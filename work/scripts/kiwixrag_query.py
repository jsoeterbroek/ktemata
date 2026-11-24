#!/usr/bin/env python3
"""Query a KiwixRAG vector index without starting its chat UI.

Installed next to KiwixRAG and run with its venv:

    /opt/ktemata-ai/kiwixrag/venv/bin/python \
        /opt/ktemata-ai/kiwixrag/kiwixrag_query.py \
        --zim /srv/kiwix/zim/book.zim --question "..." --top 6 --json

Pass multiple --zim options to search several indexes in one embedding pass. The
indexes are created by KiwixRAG's own indexer, so this file only reads Chroma and
the BGE embeddings already used there.
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
        description="Read one or more KiwixRAG indexes.",
    )
    parser.add_argument("--zim", action="append", required=True, help="ZIM file whose index to read (repeatable)")
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
    zims = [os.path.abspath(os.path.expanduser(path)) for path in args.zim]
    for zim in zims:
        if not os.path.isfile(zim):
            fail(f"ZIM not found: {zim}")
    if args.status and len(zims) != 1:
        fail("--status takes one --zim")

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

    stores = []
    for zim in zims:
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
        stores.append((zim, index_path, store, count))

    if args.status:
        zim, index_path, _store, count = stores[0]
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
        sources = []
        for zim, index_path, store, _count in stores:
            result = store.collection.query(
                query_embeddings=[embedding],
                n_results=args.top,
                include=["documents", "metadatas", "distances"],
            )
            documents = (result.get("documents") or [[]])[0]
            metadatas = (result.get("metadatas") or [[]])[0]
            distances = (result.get("distances") or [[]])[0]
            for text, meta, distance in zip(documents, metadatas, distances):
                meta = meta or {}
                distance = float(distance or 0.0)
                sources.append(
                    {
                        "text": text,
                        "title": meta.get("article_title", "Untitled"),
                        "href": meta.get("href", ""),
                        "chunk": meta.get("chunk_idx", 0),
                        "chunks": meta.get("total_chunks", 1),
                        "content_type": meta.get("content_type", "Kiwix content"),
                        "zim": os.path.basename(zim),
                        "index": index_path,
                        "distance": distance,
                        "score": 1.0 / (1.0 + max(distance, 0.0)),
                    }
                )
    except Exception as exc:
        fail(f"retrieval failed: {exc}")

    sources.sort(key=lambda source: source["score"], reverse=True)
    sources = sources[: args.top]
    if not sources:
        fail("no chunks found in the selected indexes")

    payload = {
        "zims": zims,
        "indexed": True,
        "chunks": sources,
    }
    if args.json:
        print(json.dumps(payload))
    else:
        for index, source in enumerate(sources, 1):
            print(f"[{index}] {source['title']} ({source['zim']}, {source['href']})")
            print(source["text"])
            print()
    return 0

if __name__ == "__main__":
    raise SystemExit(main())
