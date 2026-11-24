#!/usr/bin/env python3
"""Ktemata offline AI: index local documents and ask questions with Ollama.

The index is a small SQLite database of text chunks and their embeddings. `ingest` walks the
configured roots (default: /var/lib/kiwix and /srv/kiwix/zim), extracts text from common document
formats, embeds the chunks through Ollama, and stores them. `ask` embeds the question, retrieves
the closest chunks, and asks the local model to answer from those chunks only.

No network service is added here: Ollama listens on localhost and this is a CLI. The library admin
can call `ktemata-ai ask --json` to expose the same thing in its web page.

ZIM indexes and retrieval use KiwixRAG by brunuff (https://github.com/brunuff/KiwixRAG); the
installer clones it and the `zim-index` / `zim-ask` commands wrap its headless index and Chroma
store.
"""

from __future__ import annotations

import argparse
import array
import hashlib
import html
import io
import json
import math
import os
import re
import shlex
import shutil
import sqlite3
import subprocess
import sys
import time
import urllib.error
import urllib.request
import zipfile
from glob import glob
from html.parser import HTMLParser

try:
    import numpy as np
except ImportError:  # the install script adds python3-numpy; the fallback is slower, not broken
    np = None

VERSION = "1.0.0"
DEFAULT_CONFIG = "/etc/ktemata/ai.conf"

DEFAULTS = {
    "AI_MODEL": "llama3.2:3b",
    "AI_EMBED_MODEL": "nomic-embed-text",
    "AI_OLLAMA_URL": "http://127.0.0.1:11434",
    "AI_INGEST_DIRS": "/var/lib/kiwix /srv/kiwix/zim",
    "AI_DB": "/var/lib/ktemata-ai/index.sqlite3",
    "AI_CHUNK_CHARS": "1200",
    "AI_CHUNK_OVERLAP": "200",
    "AI_TOP_K": "4",
    "AI_MAX_FILE_MB": "50",
    "AI_ZIM_MODEL": "",                 # resolved to AI_MODEL unless set
    "AI_ZIM_HOME": "/srv/kiwix/zim",
    "AI_ZIM_TOP_K": "6",
    "AI_KIWIXRAG_DIR": "/opt/ktemata-ai/kiwixrag",
    "AI_KIWIX_USER": "ktemata",
}

TEXT_EXTENSIONS = {
    ".txt", ".text", ".md", ".markdown", ".rst", ".log",
    ".html", ".htm", ".xml", ".json", ".csv", ".tsv",
    ".pdf", ".epub", ".docx", ".odt",
}

SCHEMA = """
PRAGMA journal_mode=DELETE;
CREATE TABLE IF NOT EXISTS docs (
    path TEXT PRIMARY KEY,
    mtime REAL NOT NULL,
    size INTEGER NOT NULL,
    sha256 TEXT NOT NULL,
    chunks INTEGER NOT NULL,
    ingested_at REAL NOT NULL
);
CREATE TABLE IF NOT EXISTS chunks (
    id INTEGER PRIMARY KEY,
    path TEXT NOT NULL,
    ordinal INTEGER NOT NULL,
    text TEXT NOT NULL,
    embedding BLOB NOT NULL
);
CREATE INDEX IF NOT EXISTS chunks_path ON chunks(path);
CREATE TABLE IF NOT EXISTS meta (
    key TEXT PRIMARY KEY,
    value TEXT
);
"""

PROMPT = """You are Ktemata, an offline library assistant. Answer the question using only the
sources below. If the sources do not contain the answer, say that the documents do not contain it.
Do not invent facts. Keep the answer concise. Cite sources as [1], [2] and so on.

Sources:
{context}

Question: {question}
Answer:"""

ZIM_PROMPT = """You are Ktemata, an offline library assistant. Answer the question using only the
ZIM excerpts below. If the excerpts do not contain the answer, say that the archive does not
contain it. Do not invent facts. Keep the answer concise. Cite sources as [1], [2] and so on.

Excerpts:
{context}

Question: {question}
Answer:"""


class OllamaError(RuntimeError):
    def __init__(self, message: str, status: int | None = None) -> None:
        super().__init__(message)
        self.status = status


def eprint(*args: object) -> None:
    print(*args, file=sys.stderr)


def die(message: str, code: int = 1) -> None:
    eprint(f"ktemata-ai: {message}")
    raise SystemExit(code)


def read_config(path: str) -> dict[str, str]:
    cfg = dict(DEFAULTS)
    if not path or not os.path.isfile(path):
        return cfg
    try:
        with open(path, encoding="utf-8") as handle:
            for raw in handle:
                line = raw.strip()
                if not line or line.startswith("#") or "=" not in line:
                    continue
                key, value = line.split("=", 1)
                key = key.strip()
                if not re.fullmatch(r"[A-Za-z_][A-Za-z0-9_]*", key):
                    continue
                value = value.strip()
                try:
                    value = " ".join(shlex.split(value))
                except ValueError:
                    value = value.strip("\"'")
                cfg[key] = value
    except OSError as exc:
        die(f"cannot read {path}: {exc}")
    return cfg


def config_int(cfg: dict[str, str], key: str, default: int, minimum: int = 0) -> int:
    try:
        value = int(cfg.get(key, str(default)))
    except ValueError:
        value = default
    return max(minimum, value)


def ollama_base(cfg: dict[str, str]) -> str:
    return cfg["AI_OLLAMA_URL"].rstrip("/")


def http_json(url: str, payload: dict | None = None, timeout: int = 600) -> dict:
    data = None
    headers = {}
    if payload is not None:
        data = json.dumps(payload).encode("utf-8")
        headers["Content-Type"] = "application/json"
    request = urllib.request.Request(url, data=data, headers=headers)
    try:
        with urllib.request.urlopen(request, timeout=timeout) as response:
            return json.load(response)
    except urllib.error.HTTPError as exc:
        body = exc.read().decode("utf-8", "replace")
        try:
            message = json.loads(body).get("error") or body
        except ValueError:
            message = body
        raise OllamaError(f"{message.strip() or exc.reason}", exc.code) from exc
    except urllib.error.URLError as exc:
        raise OllamaError(f"cannot reach Ollama at {url}: {exc.reason}") from exc


def ollama_tags(cfg: dict[str, str]) -> list[str] | None:
    try:
        data = http_json(f"{ollama_base(cfg)}/api/tags", timeout=10)
    except OllamaError:
        return None
    names = []
    for model in data.get("models", []):
        name = model.get("name") or model.get("model")
        if name:
            names.append(name)
    return names


def model_present(names: list[str] | None, wanted: str) -> bool:
    if not names:
        return False
    return any(name == wanted or name.startswith(wanted + ":") for name in names)


def ensure_ollama(cfg: dict[str, str], model_key: str) -> None:
    names = ollama_tags(cfg)
    if names is None:
        die(
            f"Ollama is not reachable at {ollama_base(cfg)}; "
            "start it with: sudo systemctl start ollama"
        )
    wanted = cfg[model_key]
    if not model_present(names, wanted):
        die(f"model '{wanted}' is not pulled; run: ollama pull {wanted}")


def embed_batch(cfg: dict[str, str], texts: list[str]) -> list[list[float]]:
    base = ollama_base(cfg)
    model = cfg["AI_EMBED_MODEL"]
    try:
        data = http_json(f"{base}/api/embed", {"model": model, "input": texts})
        vectors = data.get("embeddings")
        if vectors and len(vectors) == len(texts):
            return vectors
    except OllamaError as exc:
        # Ollama before 0.1.26 only has /api/embeddings; fall back on 404/400. A model
        # problem (404 "model not found") also lands here, and the legacy call gives the
        # same clear error.
        if exc.status not in (400, 404):
            raise

    vectors = []
    for text in texts:
        data = http_json(f"{base}/api/embeddings", {"model": model, "prompt": text})
        vector = data.get("embedding")
        if not vector:
            raise OllamaError(f"no embedding returned for model '{model}'")
        vectors.append(vector)
    return vectors


def embed_many(cfg: dict[str, str], texts: list[str], batch_size: int = 16) -> list[list[float]]:
    vectors: list[list[float]] = []
    for start in range(0, len(texts), batch_size):
        try:
            vectors.extend(embed_batch(cfg, texts[start:start + batch_size]))
        except OllamaError as exc:
            die(f"embedding failed: {exc}")
    return vectors


def pack_vector(vector: list[float]) -> bytes:
    return array.array("f", vector).tobytes()


def unpack_vector(blob: bytes) -> array.array:
    vector = array.array("f")
    vector.frombytes(blob)
    return vector


def open_db(path: str, readonly: bool = False) -> sqlite3.Connection:
    if readonly:
        if not os.path.isfile(path):
            die(f"index not found at {path}; run: sudo ktemata-ai ingest")
        return sqlite3.connect(f"file:{path}?mode=ro", uri=True)
    directory = os.path.dirname(path) or "."
    os.makedirs(directory, exist_ok=True)
    connection = sqlite3.connect(path)
    connection.executescript(SCHEMA)
    connection.commit()
    try:
        os.chmod(path, 0o644)
    except OSError:
        pass
    return connection


def meta(connection: sqlite3.Connection) -> dict[str, str]:
    return dict(connection.execute("SELECT key, value FROM meta"))


# --------------------------------------------------------------------------- text extraction
class _HTMLText(HTMLParser):
    BLOCK = {
        "p", "div", "br", "li", "tr", "h1", "h2", "h3", "h4", "h5", "h6",
        "section", "article", "header", "footer", "blockquote", "pre", "table",
    }

    def __init__(self) -> None:
        super().__init__(convert_charrefs=True)
        self.parts: list[str] = []
        self.skip = 0

    def handle_starttag(self, tag: str, attrs) -> None:
        if tag in ("script", "style", "noscript"):
            self.skip += 1
        elif tag in self.BLOCK:
            self.parts.append("\n")

    def handle_endtag(self, tag: str) -> None:
        if tag in ("script", "style", "noscript"):
            self.skip = max(0, self.skip - 1)
        elif tag in self.BLOCK:
            self.parts.append("\n")

    def handle_data(self, data: str) -> None:
        if not self.skip:
            self.parts.append(data)

    def text(self) -> str:
        return "".join(self.parts)


def html_to_text(data: str) -> str:
    parser = _HTMLText()
    parser.feed(data)
    parser.close()
    return parser.text()


def strip_markup(data: str) -> str:
    data = re.sub(r"(?is)<(script|style|noscript).*?</\1>", " ", data)
    data = re.sub(r"(?i)</(p|div|br|li|tr|h[1-6]|section|article|text:p|text:h|w:p)>", "\n", data)
    data = re.sub(r"(?s)<[^>]+>", " ", data)
    return html.unescape(data)


def decode_bytes(data: bytes) -> str:
    for encoding in ("utf-8", "utf-16", "latin-1"):
        try:
            return data.decode(encoding)
        except (UnicodeDecodeError, LookupError):
            continue
    return data.decode("utf-8", "replace")


def extract_text(path: str, raw: bytes) -> tuple[str | None, str | None]:
    ext = os.path.splitext(path)[1].lower()
    try:
        if ext == ".pdf":
            if not shutil.which("pdftotext"):
                return None, "pdftotext is not installed (apt install poppler-utils)"
            result = subprocess.run(
                ["pdftotext", "-layout", "-enc", "UTF-8", path, "-"],
                capture_output=True,
                timeout=300,
                check=False,
            )
            if result.returncode != 0:
                message = result.stderr.decode("utf-8", "replace").strip()
                return None, message or "pdftotext failed"
            return result.stdout.decode("utf-8", "replace"), None
        if ext == ".epub":
            parts = []
            with zipfile.ZipFile(io.BytesIO(raw)) as archive:
                for name in sorted(archive.namelist()):
                    if name.lower().endswith((".xhtml", ".html", ".htm")):
                        parts.append(html_to_text(decode_bytes(archive.read(name))))
            return "\n\n".join(parts), None
        if ext == ".docx":
            with zipfile.ZipFile(io.BytesIO(raw)) as archive:
                data = decode_bytes(archive.read("word/document.xml"))
            data = data.replace("</w:p>", "\n")
            return strip_markup(data), None
        if ext == ".odt":
            with zipfile.ZipFile(io.BytesIO(raw)) as archive:
                data = decode_bytes(archive.read("content.xml"))
            return strip_markup(data), None
        text = decode_bytes(raw)
        if ext in (".html", ".htm"):
            return html_to_text(text), None
        if ext == ".xml":
            return strip_markup(text), None
        return text, None
    except (KeyError, zipfile.BadZipFile, OSError, subprocess.SubprocessError) as exc:
        return None, str(exc)


def normalize_text(text: str) -> str:
    text = text.replace("\r\n", "\n").replace("\r", "\n")
    text = re.sub(r"[ \t\f\v]+", " ", text)
    text = re.sub(r"\n[ \t]+", "\n", text)
    text = re.sub(r"\n{3,}", "\n\n", text)
    return text.strip()


def chunk_text(text: str, size: int, overlap: int) -> list[str]:
    text = normalize_text(text)
    if not text:
        return []
    size = max(200, size)
    overlap = max(0, min(overlap, size // 2))
    if len(text) <= size:
        return [text]

    paragraphs = [part.strip() for part in re.split(r"\n\s*\n", text) if part.strip()]
    chunks: list[str] = []
    current = ""
    for paragraph in paragraphs:
        if len(paragraph) > size:
            if current:
                chunks.append(current)
                current = ""
            step = max(1, size - overlap)
            for start in range(0, len(paragraph), step):
                piece = paragraph[start:start + size].strip()
                if piece:
                    chunks.append(piece)
            continue
        if len(current) + len(paragraph) + 2 <= size:
            current = f"{current}\n\n{paragraph}".strip() if current else paragraph
        else:
            if current:
                chunks.append(current)
            current = paragraph
    if current:
        chunks.append(current)
    return [chunk for chunk in chunks if chunk]


# --------------------------------------------------------------------------- ranking
def rank(cfg: dict[str, str], rows: list[tuple], query: list[float], top: int) -> list[tuple[float, tuple]]:
    if not rows:
        return []
    if np is not None:
        matrix = np.vstack([np.frombuffer(row[4], dtype=np.float32) for row in rows])
        query_vector = np.asarray(query, dtype=np.float32)
        matrix_norm = np.linalg.norm(matrix, axis=1)
        matrix_norm[matrix_norm == 0] = 1
        query_norm = float(np.linalg.norm(query_vector)) or 1.0
        scores = (matrix / matrix_norm[:, None]) @ (query_vector / query_norm)
        order = np.argsort(-scores)[:top]
        return [(float(scores[index]), rows[index]) for index in order]

    query_norm = math.sqrt(sum(value * value for value in query)) or 1.0
    scored = []
    for row in rows:
        vector = unpack_vector(row[4])
        vector_norm = math.sqrt(sum(value * value for value in vector)) or 1.0
        dot = sum(a * b for a, b in zip(query, vector))
        scored.append((dot / (query_norm * vector_norm), row))
    scored.sort(key=lambda item: item[0], reverse=True)
    return scored[:top]


# --------------------------------------------------------------------------- commands
def cmd_ingest(args: argparse.Namespace, cfg: dict[str, str]) -> int:
    roots = args.root or cfg["AI_INGEST_DIRS"].split()
    db_path = cfg["AI_DB"]
    size = config_int(cfg, "AI_CHUNK_CHARS", 1200, 200)
    overlap = config_int(cfg, "AI_CHUNK_OVERLAP", 200, 0)
    max_bytes = config_int(cfg, "AI_MAX_FILE_MB", 50, 1) * 1024 * 1024

    connection = open_db(db_path)
    ollama_checked = False
    stored_model = meta(connection).get("embed_model")
    if stored_model and stored_model != cfg["AI_EMBED_MODEL"]:
        if not args.force:
            die(
                f"index was built with '{stored_model}', config uses '{cfg['AI_EMBED_MODEL']}'; "
                "re-run: sudo ktemata-ai ingest --force"
            )
        ensure_ollama(cfg, "AI_EMBED_MODEL")
        ollama_checked = True
        print("embedding model changed; clearing the old index", file=sys.stderr)
        connection.execute("DELETE FROM chunks")
        connection.execute("DELETE FROM docs")
        connection.commit()

    seen: set[str] = set()
    processed = 0
    added_chunks = 0
    failures = 0

    for root in roots:
        if not os.path.isdir(root):
            print(f"skip root {root}: not a directory", file=sys.stderr)
            continue
        for directory, dirnames, filenames in os.walk(root):
            dirnames[:] = sorted(
                name
                for name in dirnames
                if not name.startswith(".") and not name.endswith("_rag_index")
            )
            for filename in sorted(filenames):
                if filename.startswith("."):
                    continue
                extension = os.path.splitext(filename)[1].lower()
                if extension not in TEXT_EXTENSIONS:
                    continue
                path = os.path.join(directory, filename)
                try:
                    stat = os.stat(path)
                except OSError as exc:
                    print(f"skip {path}: {exc}", file=sys.stderr)
                    failures += 1
                    continue
                seen.add(path)
                if stat.st_size > max_bytes:
                    print(f"skip {path}: larger than {max_bytes // (1024 * 1024)} MiB", file=sys.stderr)
                    continue

                try:
                    with open(path, "rb") as handle:
                        raw = handle.read()
                except OSError as exc:
                    print(f"skip {path}: {exc}", file=sys.stderr)
                    failures += 1
                    continue
                digest = hashlib.sha256(raw).hexdigest()
                row = connection.execute(
                    "SELECT sha256 FROM docs WHERE path = ?", (path,)
                ).fetchone()
                if row and row[0] == digest and not args.force:
                    print(f"unchanged {path}")
                    continue
                if args.limit and processed >= args.limit:
                    continue

                text, error = extract_text(path, raw)
                if error:
                    print(f"skip {path}: {error}", file=sys.stderr)
                    failures += 1
                    continue
                chunks = chunk_text(text or "", size, overlap)
                if not chunks:
                    print(f"skip {path}: no text extracted", file=sys.stderr)
                    continue

                if not ollama_checked:
                    ensure_ollama(cfg, "AI_EMBED_MODEL")
                    ollama_checked = True
                vectors = embed_many(cfg, chunks)
                if len(vectors) != len(chunks):
                    die(f"embedding count mismatch for {path}")

                connection.execute("DELETE FROM chunks WHERE path = ?", (path,))
                connection.execute(
                    "INSERT OR REPLACE INTO docs(path, mtime, size, sha256, chunks, ingested_at) "
                    "VALUES (?, ?, ?, ?, ?, ?)",
                    (path, stat.st_mtime, stat.st_size, digest, len(chunks), time.time()),
                )
                connection.executemany(
                    "INSERT INTO chunks(path, ordinal, text, embedding) VALUES (?, ?, ?, ?)",
                    [
                        (path, index, chunk, sqlite3.Binary(pack_vector(vector)))
                        for index, (chunk, vector) in enumerate(zip(chunks, vectors))
                    ],
                )
                connection.commit()
                processed += 1
                added_chunks += len(chunks)
                print(f"indexed {path} ({len(chunks)} chunks)")

    if not args.no_prune:
        stored = {row[0] for row in connection.execute("SELECT path FROM docs")}
        for path in sorted(stored - seen):
            connection.execute("DELETE FROM chunks WHERE path = ?", (path,))
            connection.execute("DELETE FROM docs WHERE path = ?", (path,))
            print(f"pruned {path}")
        connection.commit()

    connection.execute(
        "INSERT OR REPLACE INTO meta(key, value) VALUES ('embed_model', ?)",
        (cfg["AI_EMBED_MODEL"],),
    )
    connection.execute(
        "INSERT OR REPLACE INTO meta(key, value) VALUES ('last_ingest', ?)",
        (str(int(time.time())),),
    )
    connection.commit()
    docs = connection.execute("SELECT COUNT(*) FROM docs").fetchone()[0]
    chunks = connection.execute("SELECT COUNT(*) FROM chunks").fetchone()[0]
    print(
        f"done: {processed} document(s) indexed, {added_chunks} new chunk(s), "
        f"{docs} document(s) / {chunks} chunk(s) in the index"
    )
    if failures:
        print(f"{failures} file(s) could not be read or extracted", file=sys.stderr)
    return 0


def load_index(cfg: dict[str, str]) -> sqlite3.Connection:
    connection = open_db(cfg["AI_DB"], readonly=True)
    stored = meta(connection).get("embed_model")
    if stored and stored != cfg["AI_EMBED_MODEL"]:
        die(
            f"index was built with '{stored}', config uses '{cfg['AI_EMBED_MODEL']}'; "
            "re-run: sudo ktemata-ai ingest --force"
        )
    return connection


def retrieve(cfg: dict[str, str], question: str, top: int) -> list[tuple[float, tuple]]:
    connection = load_index(cfg)
    rows = connection.execute(
        "SELECT id, path, ordinal, text, embedding FROM chunks"
    ).fetchall()
    if not rows:
        die("the index is empty; run: sudo ktemata-ai ingest")
    ensure_ollama(cfg, "AI_EMBED_MODEL")
    query = embed_many(cfg, [question])[0]
    return rank(cfg, rows, query, top)


def cmd_search(args: argparse.Namespace, cfg: dict[str, str]) -> int:
    top = args.top or config_int(cfg, "AI_TOP_K", 4, 1)
    for score, row in retrieve(cfg, args.query, top):
        print(f"[{score:.3f}] {row[1]} (chunk {row[2] + 1})")
        snippet = re.sub(r"\s+", " ", row[3]).strip()
        print(f"    {snippet[:400]}{'…' if len(snippet) > 400 else ''}")
    return 0


def generate_answer(cfg: dict[str, str], prompt: str, model: str, timeout: int = 600) -> str:
    names = ollama_tags(cfg)
    if names is None:
        die(
            f"Ollama is not reachable at {ollama_base(cfg)}; "
            "start it with: sudo systemctl start ollama"
        )
    if model not in names:
        die(f"model '{model}' is not pulled; run: ollama pull {model}")
    try:
        data = http_json(
            f"{ollama_base(cfg)}/api/generate",
            {
                "model": model,
                "prompt": prompt,
                "stream": False,
                "options": {"temperature": 0.2, "num_ctx": 4096},
            },
            timeout=timeout,
        )
    except OllamaError as exc:
        die(f"generation failed: {exc}")
    return (data.get("response") or "").strip()


def cmd_ask(args: argparse.Namespace, cfg: dict[str, str]) -> int:
    top = args.top or config_int(cfg, "AI_TOP_K", 4, 1)
    ranked = retrieve(cfg, args.question, top)
    context = "\n\n".join(
        f"[{index}] {row[1]} (chunk {row[2] + 1})\n{row[3]}"
        for index, (_score, row) in enumerate(ranked, 1)
    )
    prompt = PROMPT.format(context=context, question=args.question)
    model = args.model or cfg["AI_MODEL"]
    if not args.json:
        eprint(f"asking {model} with {len(ranked)} source(s)…")
    answer = generate_answer(cfg, prompt, model)

    sources = [
        {"path": row[1], "ordinal": row[2] + 1, "score": round(score, 4)}
        for score, row in ranked
    ]
    if args.json:
        print(json.dumps({"answer": answer, "sources": sources, "model": model}))
        return 0
    print(answer or "(the model returned an empty answer)")
    print("\nSources:")
    for index, source in enumerate(sources, 1):
        print(f"[{index}] {source['path']} (chunk {source['ordinal']}, score {source['score']:.3f})")
    return 0


def kiwixrag_paths(cfg: dict[str, str]) -> tuple[str, str, str, str]:
    root = os.path.abspath(os.path.expanduser(cfg["AI_KIWIXRAG_DIR"]))
    return (
        root,
        os.path.join(root, "venv/bin/python"),
        os.path.join(root, "kiwixrag_index.py"),
        os.path.join(root, "kiwixrag_query.py"),
    )


def kiwixrag_index_path(zim: str) -> str:
    zim = os.path.abspath(zim)
    digest = hashlib.md5(zim.encode("utf-8")).hexdigest()[:8]
    stem = os.path.splitext(os.path.basename(zim))[0]
    return os.path.join(os.path.dirname(zim), f"{stem}_{digest}_rag_index")


def fix_index_owner(index: str, cfg: dict[str, str]) -> None:
    """Let the admin user read/write Chroma after a root-owned index build."""
    if not os.path.isdir(index):
        return
    import grp
    import pwd

    name = cfg.get("AI_KIWIX_USER") or "ktemata"
    try:
        entry = pwd.getpwnam(name)
    except KeyError:
        entry = pwd.getpwuid(os.getuid())
        name = entry.pw_name
    try:
        gid = grp.getgrnam(name).gr_gid
    except KeyError:
        gid = entry.pw_gid
    try:
        for root, dirs, files in os.walk(index):
            os.chown(root, entry.pw_uid, gid)
            os.chmod(root, 0o775)
            for child in dirs:
                path = os.path.join(root, child)
                os.chown(path, entry.pw_uid, gid)
                os.chmod(path, 0o775)
            for child in files:
                path = os.path.join(root, child)
                os.chown(path, entry.pw_uid, gid)
                os.chmod(path, 0o664)
    except PermissionError:
        eprint(f"cannot hand {index} to {name}; run zim-index as root")


def cmd_zim_index(args: argparse.Namespace, cfg: dict[str, str]) -> int:
    root, venv_python, index_helper, query_helper = kiwixrag_paths(cfg)
    if not (os.path.isfile(venv_python) and os.path.isfile(index_helper)):
        die("KiwixRAG is not installed; run: sudo ./work/scripts/post-install-ai.sh --yes")

    zim_home = os.path.abspath(os.path.expanduser(cfg["AI_ZIM_HOME"]))
    if args.zim:
        zims = [os.path.abspath(os.path.expanduser(path)) for path in args.zim]
    else:
        zims = sorted(glob(os.path.join(zim_home, "*.zim")))
    if not zims:
        die(f"no .zim files in {zim_home}")

    for zim in zims:
        if not os.path.isfile(zim):
            die(f"ZIM not found: {zim}")

    if args.status:
        if not os.path.isfile(query_helper):
            die(f"KiwixRAG query helper is missing: {query_helper}; re-run the AI installer")
        for zim in zims:
            result = subprocess.run(
                [venv_python, query_helper, "--zim", zim, "--status", "--json"],
                capture_output=True,
                text=True,
                timeout=60,
            )
            if result.returncode == 2:
                print(f"{os.path.basename(zim)}: not indexed")
                continue
            if result.returncode != 0:
                print(f"{os.path.basename(zim)}: {(result.stderr or result.stdout).strip()}")
                continue
            data = json.loads(result.stdout)
            print(f"{os.path.basename(zim)}: {data.get('chunks', 0)} chunk(s) in {data.get('index')}")
        return 0

    for zim in zims:
        command = [venv_python, index_helper, "--zim", zim]
        if args.limit:
            command += ["--limit", str(args.limit)]
        if args.rebuild:
            command.append("--rebuild")
        print(f"indexing {zim} with KiwixRAG…")
        result = subprocess.run(command, cwd=root, env=os.environ.copy())
        if result.returncode != 0:
            die(f"KiwixRAG failed for {zim} (exit {result.returncode})")
        index = kiwixrag_index_path(zim)
        fix_index_owner(index, cfg)
        if args.json:
            print(json.dumps({"zim": zim, "index": index, "indexed": True}))
        else:
            print(f"indexed {zim} -> {index}")
    return 0





def cmd_zim_ask(args: argparse.Namespace, cfg: dict[str, str]) -> int:
    root, venv_python, index_helper, helper = kiwixrag_paths(cfg)
    if not (os.path.isfile(venv_python) and os.path.isfile(helper)):
        die("KiwixRAG is not installed; run: sudo ./work/scripts/post-install-ai.sh --yes")

    zim_home = os.path.abspath(os.path.expanduser(cfg["AI_ZIM_HOME"]))
    zims = sorted(glob(os.path.join(zim_home, "*.zim")))
    if args.zim:
        selected = os.path.abspath(os.path.expanduser(args.zim))
        if not os.path.isfile(selected):
            die(f"ZIM not found: {selected}")
    elif len(zims) == 1:
        selected = zims[0]
    elif not zims:
        die(f"no .zim files in {zim_home}")
    else:
        die("multiple ZIM archives found; choose one with --zim")

    top = args.top or config_int(cfg, "AI_ZIM_TOP_K", 6, 1)
    try:
        result = subprocess.run(
            [
                venv_python,
                helper,
                "--zim", selected,
                f"--question={args.question}",
                "--top", str(top),
                "--json",
            ],
            capture_output=True,
            text=True,
            timeout=300,
        )
    except subprocess.TimeoutExpired:
        die("KiwixRAG retrieval timed out")
    except OSError as exc:
        die(f"cannot run {helper}: {exc}")
    if result.returncode != 0:
        lines = (result.stderr or result.stdout).strip().splitlines()
        message = lines[-1] if lines else f"exit {result.returncode}"
        die(message)
    try:
        data = json.loads(result.stdout)
    except ValueError:
        die("KiwixRAG returned invalid JSON")
    chunks = data.get("chunks") or []
    if not chunks:
        die("the KiwixRAG index returned no chunks; rebuild it with: "
            f"sudo ktemata-ai zim-index --zim {selected} --rebuild")

    context = "\n\n".join(
        f"[{index}] {chunk.get('title', 'Untitled')} ({chunk.get('href', '')})\n"
        f"{chunk.get('text', '')}"
        for index, chunk in enumerate(chunks, 1)
    )
    model = (args.model or cfg.get("AI_ZIM_MODEL") or cfg["AI_MODEL"]).removeprefix("ollama/")
    if not args.json:
        eprint(f"asking {model} with {len(chunks)} KiwixRAG chunk(s)…")
    answer = generate_answer(
        cfg,
        ZIM_PROMPT.format(context=context, question=args.question),
        model,
    )
    sources = [
        {
            "title": chunk.get("title", ""),
            "path": chunk.get("href", ""),
            "chunk": int(chunk.get("chunk", 0)) + 1,
        }
        for chunk in chunks
    ]
    if args.json:
        print(json.dumps({
            "answer": answer,
            "sources": sources,
            "model": model,
            "zim": selected,
        }))
        return 0
    print(answer or "(the model returned an empty answer)")
    print("\nSources:")
    for index, source in enumerate(sources, 1):
        print(f"[{index}] {source['title']} ({source['path']}, chunk {source['chunk']})")
    return 0


def cmd_status(args: argparse.Namespace, cfg: dict[str, str]) -> int:
    db_path = cfg["AI_DB"]
    docs = chunks = 0
    last_ingest = 0
    db_bytes = 0
    if os.path.isfile(db_path):
        db_bytes = os.path.getsize(db_path)
        try:
            connection = sqlite3.connect(f"file:{db_path}?mode=ro", uri=True)
            docs = connection.execute("SELECT COUNT(*) FROM docs").fetchone()[0]
            chunks = connection.execute("SELECT COUNT(*) FROM chunks").fetchone()[0]
            last_ingest = int(meta(connection).get("last_ingest", "0") or 0)
        except sqlite3.Error:
            pass
    names = ollama_tags(cfg)
    root, venv_python, index_helper, helper = kiwixrag_paths(cfg)
    zim_home = os.path.abspath(os.path.expanduser(cfg["AI_ZIM_HOME"]))
    zims = sorted(glob(os.path.join(zim_home, "*.zim")))
    zim_model = cfg.get("AI_ZIM_MODEL") or cfg["AI_MODEL"]
    indexed = [
        {
            "name": os.path.basename(zim),
            "index": kiwixrag_index_path(zim),
            "indexed": os.path.isfile(os.path.join(kiwixrag_index_path(zim), "metadata.json")),
        }
        for zim in zims
    ]
    payload = {
        "installed": True,
        "db": db_path,
        "db_bytes": db_bytes,
        "docs": docs,
        "chunks": chunks,
        "last_ingest": last_ingest,
        "model": cfg["AI_MODEL"],
        "embed_model": cfg["AI_EMBED_MODEL"],
        "ollama": names is not None,
        "ollama_models": names or [],
        "ingest_dirs": cfg["AI_INGEST_DIRS"].split(),
        "kiwixrag": {
            "installed": all(os.path.isfile(path) for path in (venv_python, index_helper, helper)),
            "dir": root,
            "home": zim_home,
            "files": len(zims),
            "indexed": sum(1 for item in indexed if item["indexed"]),
            "zims": indexed,
            "model": zim_model,
            "top_k": config_int(cfg, "AI_ZIM_TOP_K", 6, 1),
        },
    }
    if args.json:
        print(json.dumps(payload))
        return 0
    print(f"model       {cfg['AI_MODEL']}")
    print(f"embeddings  {cfg['AI_EMBED_MODEL']}")
    print(f"index       {db_path} ({db_bytes} bytes)")
    print(f"documents   {docs}")
    print(f"chunks      {chunks}")
    print(f"last ingest {time.strftime('%Y-%m-%d %H:%M:%S', time.localtime(last_ingest)) if last_ingest else 'never'}")
    print(f"roots       {' '.join(cfg['AI_INGEST_DIRS'].split())}")
    print(f"zim index   {payload['kiwixrag']['indexed']}/{len(zims)} archive(s) in {zim_home}, "
          f"KiwixRAG {'ready' if payload['kiwixrag']['installed'] else 'missing'}, model {zim_model}")
    print(f"ollama      {'reachable' if names is not None else 'not reachable'}")
    return 0


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        prog="ktemata-ai",
        description="Offline AI over local documents, backed by Ollama.",
    )
    parser.add_argument("--version", action="version", version=f"%(prog)s {VERSION}")
    parser.add_argument("--config", default=DEFAULT_CONFIG, help=f"configuration (default {DEFAULT_CONFIG})")
    sub = parser.add_subparsers(dest="command", required=True)

    ingest = sub.add_parser("ingest", help="index documents")
    ingest.add_argument("--root", action="append", help="directory to scan (repeatable; overrides config)")
    ingest.add_argument("--force", action="store_true", help="re-index unchanged files")
    ingest.add_argument("--limit", type=int, default=0, help="index at most N changed files")
    ingest.add_argument("--no-prune", action="store_true", help="keep entries for missing files")
    ingest.set_defaults(func=cmd_ingest)

    ask = sub.add_parser("ask", help="ask a question over the indexed documents")
    ask.add_argument("question")
    ask.add_argument("--top", type=int, default=0, help="number of chunks to retrieve")
    ask.add_argument("--model", default="", help="override AI_MODEL")
    ask.add_argument("--json", action="store_true", help="machine-readable output")
    ask.set_defaults(func=cmd_ask)

    search = sub.add_parser("search", help="show the closest chunks without asking the model")
    search.add_argument("query")
    search.add_argument("--top", type=int, default=0, help="number of chunks to retrieve")
    search.set_defaults(func=cmd_search)

    status = sub.add_parser("status", help="show model, index and Ollama state")
    status.add_argument("--json", action="store_true", help="machine-readable output")
    status.set_defaults(func=cmd_status)

    zim_index = sub.add_parser(
        "zim-index",
        help="build or inspect KiwixRAG vector indexes for ZIM files",
    )
    zim_index.add_argument("--zim", action="append", help="ZIM file to index (repeatable; default: all in AI_ZIM_HOME)")
    zim_index.add_argument("--limit", type=int, default=0, help="index at most N articles per ZIM (default: all)")
    zim_index.add_argument("--rebuild", action="store_true", help="discard and rebuild an existing index")
    zim_index.add_argument("--status", action="store_true", help="show index state instead of building")
    zim_index.add_argument("--json", action="store_true", help="machine-readable output")
    zim_index.set_defaults(func=cmd_zim_index)

    zim_ask = sub.add_parser(
        "zim-ask",
        help="ask a question over a KiwixRAG index",
    )
    zim_ask.add_argument("question")
    zim_ask.add_argument("--zim", default="", help="ZIM file whose index to query")
    zim_ask.add_argument("--top", type=int, default=0, help="chunks to retrieve (default AI_ZIM_TOP_K)")
    zim_ask.add_argument("--model", default="", help="override AI_ZIM_MODEL")
    zim_ask.add_argument("--json", action="store_true", help="machine-readable output")
    zim_ask.set_defaults(func=cmd_zim_ask)
    return parser


def main(argv: list[str] | None = None) -> int:
    parser = build_parser()
    args = parser.parse_args(argv)
    cfg = read_config(args.config)
    cfg["AI_ZIM_MODEL"] = cfg.get("AI_ZIM_MODEL") or cfg["AI_MODEL"]
    return int(args.func(args, cfg) or 0)


if __name__ == "__main__":
    raise SystemExit(main())
