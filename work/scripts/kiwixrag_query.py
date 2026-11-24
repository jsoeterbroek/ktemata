#!/usr/bin/env python3
"""Query a KiwixRAG vector index without starting its chat UI.

Installed next to KiwixRAG and run with its venv:

    /opt/ktemata-ai/kiwixrag/venv/bin/python \
        /opt/ktemata-ai/kiwixrag/kiwixrag_query.py \
        --zim /srv/kiwix/zim/book.zim --question "..." --top 6 --json

The index is created by KiwixRAG's own `kiwix_chat.py --build-index`, so this
file only reads Chroma and the BGE embeddings already used there.
"""

from __future__ import annotations

import argparse
import json
import os
import sys

# Keep the BGE cache inside the KiwixRAG install so systemd units with ProtectHome can read it.
_HERE = os.path.dirname(os.path.abspath(__file__))
os.environ.setdefault("HF_HOME", os.path.join(_HERE, ".cache/huggingface"))


def fail(message: str, code: int = 1) -> None:
    print(f"kiwixrag_query: {message}", file=sys.stderr)
    raise SystemExit(code)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        prog="kiwixrag_query",
        description="Read a KiwixRAG index for one ZIM file.",
    )
    parser.add_argument("--zim", required=True, help="ZIM file whose index to read")
    parser.add_argument("--question", default="", help="question to embed and retrieve")
    parser.add_argument("--top", type=int, default=6, help="chunks to return (default 6)")
    parser.add_argument("--status", action="store_true", help="print index state and exit")
    parser.add_argument("--json", action="store_true", help="machine-readable output")
    args = parser.parse_args()
    if args.top < 1:
        fail("--top must be at least 1")
    return args


def main() -> int:
    args = parse_args()
    zim = os.path.abspath(os.path.expanduser(args.zim))
    if not os.path.isfile(zim):
        fail(f"ZIM not found: {zim}")

    here = os.path.dirname(os.path.abspath(__file__))
    if here not in sys.path:
        sys.path.insert(0, here)

    try:
        from kiwix_chat.rag.vector_store import (
            get_index_path,
            get_vector_store,
            is_indexed,
        )
    except ImportError as exc:
        fail(f"KiwixRAG is not importable ({exc}); run the AI installer", 3)

    index_path = get_index_path(zim)
    if not is_indexed(zim) or not os.path.isfile(os.path.join(index_path, "metadata.json")):
        fail(
            f"no complete KiwixRAG index for {zim}; build it with: "
            f"sudo ktemata-ai zim-index --zim {zim}",
            2,
        )

    try:
        store = get_vector_store(zim)
        count = store.get_collection_size()
    except Exception as exc:
        fail(f"cannot open the KiwixRAG index at {index_path}: {exc}")

    if args.status:
        payload = {
            "zim": zim,
            "index": index_path,
            "indexed": True,
            "chunks": count,
        }
        if args.json:
            print(json.dumps(payload))
        else:
            print(f"zim      {zim}")
            print(f"index    {index_path}")
            print(f"chunks   {count}")
        return 0

    if not args.question.strip():
        fail("--question is required unless --status is used")

    try:
        from kiwix_chat.rag.embeddings import generate_embedding

        embedding = generate_embedding(args.question, is_query=True)
        chunks = store.hybrid_search(
            query=args.question,
            query_embedding=embedding,
            top_k=args.top,
        )
    except Exception as exc:
        fail(f"retrieval failed: {exc}")

    sources = [
        {
            "text": chunk.text,
            "title": chunk.article_title,
            "href": chunk.href,
            "chunk": chunk.chunk_idx,
            "chunks": chunk.total_chunks,
            "content_type": chunk.content_type,
        }
        for chunk in chunks
    ]
    payload = {
        "zim": zim,
        "index": index_path,
        "indexed": True,
        "chunks": sources,
    }
    if args.json:
        print(json.dumps(payload))
    else:
        for index, source in enumerate(sources, 1):
            print(f"[{index}] {source['title']} ({source['href']})")
            print(source["text"])
            print()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
