#!/usr/bin/env python3
"""Build a KiwixRAG Chroma index for one ZIM, without KiwixRAG's chat UI.

KiwixRAG's own indexer enumerates articles through kiwix-serve, assumes port 8081
(the Ktemata admin port), and relies on a sitemap that current kiwix-serve builds do
not expose for a single archive. This wrapper keeps KiwixRAG's chunker, BGE
embeddings, Chroma store and metadata, but reads articles directly with zimdump.
That also works for book ZIMs with no usable full-text index.

KiwixRAG is by brunuff: https://github.com/brunuff/KiwixRAG
"""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import shutil
import subprocess
import sys
from typing import Iterator

# Keep the BGE cache inside the KiwixRAG install so systemd units with ProtectHome can read it.
_HERE = os.path.dirname(os.path.abspath(__file__))
os.environ.setdefault("HF_HOME", os.path.join(_HERE, ".cache/huggingface"))


def fail(message: str, code: int = 1) -> None:
    print(f"kiwixrag_index: {message}", file=sys.stderr)
    raise SystemExit(code)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        prog="kiwixrag_index",
        description="Build a KiwixRAG vector index for one ZIM file.",
    )
    parser.add_argument("--zim", required=True, help="ZIM file to index")
    parser.add_argument("--limit", type=int, default=0, help="index at most N text articles (default all)")
    parser.add_argument("--rebuild", action="store_true", help="clear an existing index first")
    args = parser.parse_args()
    if args.limit < 0:
        fail("--limit must be zero (all) or positive")
    return args


def iter_articles(zimdump: str, zim: str, limit: int) -> Iterator[tuple[str, str]]:
    """Yield (title, href) for readable text entries, across namespaces."""
    process = subprocess.Popen(
        [zimdump, "list", "--details", zim],
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
        errors="replace",
    )
    count = 0
    path = ""
    title = ""
    try:
        assert process.stdout is not None
        for line in process.stdout:
            stripped = line.strip()
            if stripped.startswith("path:"):
                path = stripped.split(":", 1)[1].strip()
                title = ""
                continue
            if stripped.startswith("title:"):
                title = stripped.split(":", 1)[1].strip()
                continue
            if not stripped.startswith("* mime-type:") or not path:
                continue
            mime = stripped.split(":", 1)[1].strip().lower()
            if not (mime.startswith("text/html") or mime.startswith("text/plain")):
                path = ""
                continue
            count += 1
            yield title or os.path.basename(path), path
            path = ""
            if limit and count >= limit:
                break
    finally:
        if process.poll() is None:
            process.terminate()
        try:
            process.wait(timeout=5)
        except subprocess.TimeoutExpired:
            process.kill()
            process.wait(timeout=5)
    stderr = process.stderr.read().strip() if process.stderr is not None else ""
    if count == 0 and process.returncode not in (0, -15, 143):
        fail(f"zimdump list --details failed for {zim}: {stderr or 'unknown error'}")


def read_article(zimdump: str, zim: str, href: str) -> str:
    try:
        result = subprocess.run(
            [zimdump, "show", f"--url={href}", zim],
            capture_output=True,
            timeout=120,
            check=False,
        )
    except subprocess.TimeoutExpired:
        print(f"skip {href}: zimdump timed out", file=sys.stderr)
        return ""
    if result.returncode != 0 or not result.stdout.strip():
        return ""
    if b"\x00" in result.stdout[:2048]:
        return ""
    return result.stdout.decode("utf-8", "replace")


def zim_hash(zim: str) -> str:
    with open(zim, "rb") as handle:
        head = handle.read(1024 * 1024)
    return hashlib.md5(head + str(os.path.getsize(zim)).encode()).hexdigest()[:16]


def save_metadata(zim: str, index: str, article_count: int, chunk_count: int, content_type: str) -> None:
    os.makedirs(index, exist_ok=True)
    payload = {
        "zim_file": zim,
        "zim_hash": zim_hash(zim),
        "article_count": article_count,
        "chunk_count": chunk_count,
        "content_type": content_type,
    }
    with open(os.path.join(index, "metadata.json"), "w", encoding="utf-8") as handle:
        json.dump(payload, handle, indent=2)


def main() -> int:
    args = parse_args()
    zim = os.path.abspath(os.path.expanduser(args.zim))
    if not os.path.isfile(zim):
        fail(f"ZIM not found: {zim}")

    here = os.path.dirname(os.path.abspath(__file__))
    if here not in sys.path:
        sys.path.insert(0, here)

    zimdump = shutil.which("zimdump")
    if not zimdump:
        fail("zimdump is not installed; run: sudo apt install zim-tools")

    try:
        from kiwix_chat.kiwix.client import get_zim_content_description, set_global_zim_file_path
        from kiwix_chat.kiwix.parser import HTMLParserWithLinks
        from kiwix_chat.rag.chunker import chunk_article
        from kiwix_chat.rag.vector_store import get_index_path, get_vector_store, is_indexed
    except ImportError as exc:
        fail(f"KiwixRAG is not importable ({exc}); run the AI installer", 3)

    set_global_zim_file_path(zim)
    metadata = os.path.join(get_index_path(zim), "metadata.json")
    existing = is_indexed(zim)
    if existing and not args.rebuild:
        if os.path.isfile(metadata):
            print(f"index already exists for {zim}; use --rebuild to replace it", file=sys.stderr)
            return 0
        print("partial index without metadata; rebuilding it", file=sys.stderr)
    if not existing:
        try:
            os.unlink(metadata)
        except FileNotFoundError:
            pass

    store = get_vector_store(zim)
    if args.rebuild or existing:
        # The admin uses metadata.json as its ready marker. Remove it before clearing so a
        # failed rebuild cannot leave a "ready" badge over an empty collection.
        try:
            os.unlink(metadata)
        except FileNotFoundError:
            pass
        store.clear()

    content_type = get_zim_content_description()
    article_count = 0
    chunk_count = 0
    batch: list = []
    try:
        for title, href in iter_articles(zimdump, zim, args.limit):
            raw = read_article(zimdump, zim, href)
            if not raw:
                continue
            parser = HTMLParserWithLinks()
            parser.feed(raw)
            text = "\n".join(
                line.strip() for line in parser.get_text().splitlines() if line.strip()
            )
            if not text:
                continue
            chunks = chunk_article(
                text=text,
                title=title,
                href=href,
                max_chunk_size=500,
                overlap=50,
                content_type=content_type,
            )
            if not chunks:
                continue
            batch.extend(chunks)
            article_count += 1
            chunk_count += len(chunks)
            if len(batch) >= 100:
                store.add_chunks(batch)
                print(
                    f"[rag] indexed {article_count} articles, {chunk_count} chunks",
                    file=sys.stderr,
                )
                batch = []
        if batch:
            store.add_chunks(batch)
    except KeyboardInterrupt:
        if batch:
            store.add_chunks(batch)
        print("indexing interrupted; partial chunks were saved", file=sys.stderr)
        return 1

    if not chunk_count:
        fail(
            f"no readable text articles in {zim}; "
            f"inspect with: zimdump info {zim}; zimdump list --details {zim}"
        )

    save_metadata(
        zim,
        get_index_path(zim),
        article_count,
        chunk_count,
        content_type,
    )
    print(
        f"[rag] index complete: {article_count} articles, {chunk_count} chunks in "
        f"{get_index_path(zim)}",
        file=sys.stderr,
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
