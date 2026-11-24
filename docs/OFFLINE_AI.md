# Offline AI

Ktemata answers questions from its own documents and from ZIM archives without an internet
connection. The stack is deliberately split:

- **Ollama** runs a quantised instruction model on the Pi and listens on `127.0.0.1:11434`.
- **ktemata-ai** extracts text from documents, chunks it, embeds the chunks through Ollama, and
  stores them in a SQLite index. `ask` retrieves chunks and answers from them only.
- **KiwixRAG** builds a separate vector index for ZIM archives with sentence-transformers (BGE)
  and ChromaDB. `zim-ask` retrieves chunks from that index and uses the same local Ollama model
  to answer.

KiwixRAG is by [brunuff](https://github.com/brunuff/KiwixRAG). The installer clones it at install
time; its source is not vendored here.

Nothing is exposed on the LAN by the AI itself. The CLI is local, and the existing library admin
on `:8081` gains **Ask the library**, **Ask ZIM**, and **AI index** controls for each ZIM archive.

This is a separate install because it downloads models and changes the memory/thermal profile.
The base [`post-install.sh`](POST_INSTALL.md) stays the same unless you pass `--ai`.

## What gets read

The document roots are:

```
/var/lib/kiwix          # Kiwix state and any documents you put here
/srv/kiwix/zim          # the ZIM library directory
```

Text is extracted recursively from:

| Extension | How |
|---|---|
| `.txt`, `.md`, `.markdown`, `.rst`, `.log`, `.csv`, `.tsv`, `.json` | read as text |
| `.html`, `.htm` | HTML parser, scripts/styles dropped |
| `.xml` | tags stripped |
| `.pdf` | `pdftotext` (`poppler-utils`) |
| `.epub` | every XHTML/HTML member |
| `.docx` | `word/document.xml` |
| `.odt` | `content.xml` |

Hidden files and names are skipped, as are files larger than `AI_MAX_FILE_MB` (default 50).

**ZIM is not part of the document index.** A `.zim` is a compressed archive with its own article
store. KiwixRAG indexes it separately, next to the archive, and `zim-ask` reads that index. The
normal six-hour `ktemata-ai ingest` timer does not rebuild ZIM indexes.

## Hardware and expectations

A Pi 5 with **8 GB** is the reference. Defaults:

| Component | Default | Approx. download | Memory |
|---|---|---|---|
| generation model | `llama3.2:3b` (Q4) | ~2 GB | ~2.5 GB |
| document embeddings | `nomic-embed-text` (Ollama) | ~274 MB | ~0.5 GB |
| KiwixRAG dependencies | sentence-transformers, ChromaDB, torch | ~1.5 GB | ~1 GB during indexing |
| KiwixRAG embeddings | `BAAI/bge-base-en-v1.5` | ~110 MB | ~0.5 GB |
| document index | SQLite in `/var/lib/ktemata-ai/` | — | grows with text |

Expect a few tokens per second on CPU. `--model llama3.2:1b` is faster and weaker; `qwen2.5:3b`
is another 3B option. ZIM indexing is CPU-heavy and can take from minutes for a small book ZIM to
hours for a large Wikipedia archive. The index build writes checkpoints every batch and can be
interrupted.

Plan for roughly **5 GB** of free space before the first install: Ollama models, the KiwixRAG
Python environment, the BGE model, and the document index.

## Install

Run the separate installer directly:

```bash
sudo ./work/scripts/post-install-ai.sh --yes
```

Or let the main installer do it at the end:

```bash
sudo ./work/scripts/post-install.sh --ai
```

Options:

```bash
sudo ./work/scripts/post-install-ai.sh --model llama3.2:1b
sudo ./work/scripts/post-install-ai.sh --no-models --no-ingest     # offline, preloaded
sudo ./work/scripts/post-install-ai.sh --no-service                # no six-hour document timer
sudo ./work/scripts/post-install-ai.sh --ingest-dir /srv/docs       # repeatable
sudo ./work/scripts/post-install-ai.sh --zim-index                  # index existing ZIMs now
sudo ./work/scripts/post-install-ai.sh --no-kiwixrag                # documents only
./work/scripts/post-install-ai.sh --dry-run                         # no root, no changes
```

What it does:

1. installs `python3-numpy`, `python3-venv`, `poppler-utils`, `zim-tools`, `git`, `curl`,
   `ca-certificates`, `zstd`;
2. installs Ollama with the official installer if `ollama` is absent, and enables
   `ollama.service`;
3. pulls the embedding and generation models through Ollama's API (skip with `--no-models`);
4. installs `/usr/local/bin/ktemata-ai` and `/etc/ktemata/ai.conf`;
5. clones [brunuff/KiwixRAG](https://github.com/brunuff/KiwixRAG) into
   `/opt/ktemata-ai/kiwixrag`, creates its own venv, installs
   `sentence-transformers`/`chromadb`/`tiktoken` with
   [`kiwixrag-constraints.txt`](../work/scripts/kiwixrag-constraints.txt), and warms the BGE model;
6. installs `ktemata-ai-zim-index@.service`, the on-demand unit the admin uses to build a ZIM
   index in the background;
7. updates the library admin UI and server with **Ask the library**, **Ask ZIM**, and the **AI index**
   column, restarting `ktemata-admin.service` if installed;
8. runs the first `ktemata-ai ingest` (skip with `--no-ingest`);
9. installs and enables `ktemata-ai-ingest.timer` for a document re-index every six hours.

A re-run is idempotent. An existing `/etc/ktemata/ai.conf` is the source of truth: the installer
uses its models and roots instead of the flags, and only appends missing KiwixRAG keys. Edit the
file to change them. The KiwixRAG checkout follows the `main` branch unless `AI_KIWIXRAG_REF` is
set for the installer run.

The upstream project describes itself as a work in progress. There is no release to pin, so the
installer follows the configured branch and constrains `chromadb`/`sentence-transformers` with
`work/scripts/kiwixrag-constraints.txt`; re-running it updates the checkout and reuses the venv.

## Configuration

`/etc/ktemata/ai.conf`, mode `0644` (it contains no secrets):

```bash
AI_MODEL=llama3.2:3b
AI_EMBED_MODEL=nomic-embed-text
AI_OLLAMA_URL=http://127.0.0.1:11434
AI_INGEST_DIRS="/var/lib/kiwix /srv/kiwix/zim"
AI_DB=/var/lib/ktemata-ai/index.sqlite3
AI_CHUNK_CHARS=1200
AI_CHUNK_OVERLAP=200
AI_TOP_K=4
AI_MAX_FILE_MB=50
AI_ZIM_MODEL=llama3.2:3b
AI_ZIM_HOME=/srv/kiwix/zim
AI_ZIM_TOP_K=6
AI_KIWIXRAG_DIR=/opt/ktemata-ai/kiwixrag
AI_KIWIX_USER=ktemata
```

| Key | Meaning |
|---|---|
| `AI_MODEL` | Ollama model used to answer document questions |
| `AI_EMBED_MODEL` | Ollama embedding model; changing it requires `ingest --force` |
| `AI_OLLAMA_URL` | API endpoint, localhost by default |
| `AI_INGEST_DIRS` | space-separated document roots; paths must not contain spaces |
| `AI_DB` | SQLite document index |
| `AI_CHUNK_CHARS` | target document chunk size in characters |
| `AI_CHUNK_OVERLAP` | overlap for long document paragraphs |
| `AI_TOP_K` | document chunks retrieved per question |
| `AI_MAX_FILE_MB` | skip larger documents |
| `AI_ZIM_MODEL` | Ollama model for ZIM answers |
| `AI_ZIM_HOME` | directory containing `*.zim`; used by `zim-index` and `zim-ask` |
| `AI_ZIM_TOP_K` | KiwixRAG chunks retrieved per ZIM question |
| `AI_KIWIXRAG_DIR` | KiwixRAG checkout and its `venv` |
| `AI_KIWIX_USER` | owner/group of a completed index, so the admin can open Chroma |

The file is sourced by the installer when it exists, so keep it root-owned and not writable by
group/other (`chmod 644`, `chown root:root`).

## Use

```bash
ktemata-ai status                 # models, document counts, ZIM index counts, Ollama state
ktemata-ai ingest                 # add/update changed documents, prune deleted ones
sudo ktemata-ai ingest --force    # re-embed every document
ktemata-ai search "keyword"       # closest document chunks, no model
ktemata-ai ask "What does the manual say about charging?"
ktemata-ai ask "..." --json       # {answer, sources, model}

sudo ktemata-ai zim-index --zim /srv/kiwix/zim/book.zim
ktemata-ai zim-ask --zim /srv/kiwix/zim/book.zim "What does the book say about cooking?"
```

`ingest` hashes each document and only embeds changed content. `--root DIR` overrides the
configured roots for one run; `--limit N` bounds a first test.

### ZIM indexing with KiwixRAG

`zim-index` uses KiwixRAG's chunker, BGE embeddings, Chroma store and metadata, and stores the
index beside the archive. It reads articles directly with `zimdump`, so it does not need a
`kiwix-serve` listener and works when the ZIM has no usable full-text index:

```
/srv/kiwix/zim/book.zim
/srv/kiwix/zim/book_<8-char-md5>_rag_index/
```

Articles are chunked at 500 characters with 50-character overlap and embedded in batches of
100 chunks. Enumerating through `zimdump` also handles book ZIMs whose articles live outside
namespace `A`; only `text/html` and `text/plain` entries are indexed.

The upstream `kiwix_chat.py --build-index` path is not used: it expects `sitemap.xml` from
`kiwix-serve` (current builds return 404 for a single archive) and a server on `:8081`, which the
Ktemata admin owns. `kiwixrag_index.py` calls KiwixRAG's own chunker, embeddings and Chroma store
directly, with `zimdump` for article enumeration.

```bash
# one archive, all articles
sudo ktemata-ai zim-index --zim /srv/kiwix/zim/book.zim

# smoke test: index at most 50 articles
sudo ktemata-ai zim-index --zim /srv/kiwix/zim/book.zim --limit 50

# every *.zim in AI_ZIM_HOME
sudo ktemata-ai zim-index

# inspect or discard
ktemata-ai zim-index --zim /srv/kiwix/zim/book.zim --status
sudo ktemata-ai zim-index --zim /srv/kiwix/zim/book.zim --rebuild
```

| Option | Meaning |
|---|---|
| `--zim FILE` | ZIM to index; repeatable; default all in `AI_ZIM_HOME` |
| `--limit N` | index at most N text articles per ZIM |
| `--rebuild` | discard the existing Chroma collection and rebuild |
| `--status` | print the index path and chunk count; do not build |
| `--json` | machine-readable result |

Run it as root. After the build, `zim-index` hands the index directory to `AI_KIWIX_USER`
(default `ktemata`) with group read/write, so the admin service can open Chroma without running as
root. A very large archive can take hours; the command prints KiwixRAG's progress and can be
interrupted. The next run clears the partial collection before rebuilding.

### ZIM questions

`zim-ask` embeds the question with the same BGE model, retrieves the closest chunks from Chroma,
and asks the Ollama model to answer from those chunks only. It prints the article title, href and
chunk for each source.

```bash
ktemata-ai zim-ask --zim /srv/kiwix/zim/book.zim "What are the benefits of cooking food?"
ktemata-ai zim-ask --zim /srv/kiwix/zim/book.zim "..." --top 8
ktemata-ai zim-ask --zim /srv/kiwix/zim/book.zim "..." --json
```

The index is per archive; `--zim` is required when `AI_ZIM_HOME` contains more than one `.zim`.
If the index is missing, build it first. The answer is only as good as the retrieved chunks: a
single very large article is split into KiwixRAG chunks (500 characters, 50 overlap), and
`AI_ZIM_TOP_K` controls how many are sent to the model.

### From the library admin

`http://<device>:8081/` has:

- **Ask the library** for the document index, with source paths and chunks.
- **Ask ZIM** for an archive with a KiwixRAG index; it calls `zim-ask --json` and lists the
  matching article titles and chunks. It stays disabled until at least one index exists.
- **AI index** controls in each ZIM row:
  - **Build** starts `ktemata-ai-zim-index@<name>.service` in the background;
  - **Rebuild** does the same with `--rebuild`;
  - the badge changes to **Indexing** while the unit is active and **AI ready** when the metadata
    is present;
  - **AI off** means KiwixRAG is not installed.

The admin service is root, but the index build is a separate systemd oneshot. The page polls the
unit's `ActiveState`/`Result`; it does not hold an HTTP request open for hours. Check progress
with:

```bash
journalctl -u 'ktemata-ai-zim-index@*' -f
```

Both forms are in the same AI panel: **Ask the library** uses the SQLite document index, and
**Ask ZIM** uses the selected KiwixRAG Chroma index. The CLI remains `ktemata-ai zim-ask`.

The admin page is protected by HTTP Basic auth, but there is no TLS. Keep it on the hotspot or a
trusted LAN, or bind it to loopback and use an SSH tunnel.

## Re-indexing

The timer runs the service at boot + 5 minutes and every 6 hours:

```bash
systemctl list-timers ktemata-ai-ingest.timer
systemctl status ktemata-ai-ingest
journalctl -u ktemata-ai-ingest -f
sudo systemctl start ktemata-ai-ingest     # documents now
```

ZIM indexes are not on this timer. Rebuild one after replacing or updating its archive:

```bash
sudo ktemata-ai zim-index --zim /srv/kiwix/zim/book.zim --rebuild
```

A large document index can take a while; the service has a one-hour start timeout. Re-run
`ktemata-ai ingest` by hand to see progress.

## Offline models

`--no-models` skips the Ollama downloads. To move Ollama models to an isolated box, pull them on a
connected machine with the same Ollama version, then copy the model store:

```bash
# connected machine
ollama pull llama3.2:3b
ollama pull nomic-embed-text

# Ktemata (service store)
sudo systemctl stop ollama
sudo rsync -a /path/to/models/ /usr/share/ollama/.ollama/models/
sudo chown -R ollama:ollama /usr/share/ollama/.ollama/models
sudo systemctl start ollama
ollama list
```

Then run the installer with `--no-models` (and `--no-ingest` if you want to start the index later).

KiwixRAG also needs its Python wheels and the BGE model. On a connected machine, run the installer
once (or `pip install -r /opt/ktemata-ai/kiwixrag/requirements.txt` inside its venv) and let
`sentence-transformers` download `BAAI/bge-base-en-v1.5`. The installer pins `HF_HOME` to
`/opt/ktemata-ai/kiwixrag/.cache/huggingface`; copy that directory with the KiwixRAG checkout to
the isolated box. `--no-models` skips the warm-up but does not remove an existing model cache.

## Security and limits

- Ollama binds `127.0.0.1`; no API port is opened on the LAN.
- KiwixRAG's dependencies and the BGE model are downloaded from PyPI/Hugging Face at install time.
  At runtime `zim-index` reads the ZIM with `zimdump`; `zim-ask` reads Chroma and calls Ollama.
  Neither adds a listening service.
- The admin page is authenticated; the AI routes are under the same auth.
- The document ingest service runs as root because it reads the library and writes the index. It is
  `ProtectSystem=strict` with only the index directory writable. The ZIM index unit has only the
  ZIM directory writable.
- The model can be wrong. Both prompts restrict it to the retrieved sources and print them; always
  check the cited document path or ZIM article/chunk for a factual answer.
- Large PDFs and OCR-free scans produce poor document text. A ZIM with no readable text entries
  produces an empty KiwixRAG index; inspect it with `zimdump info` / `zimdump list --details`.
- KiwixRAG's deduplication is per article in its own retriever; `zim-ask` uses the raw hybrid
  top-k so a single large article still contributes several chunks.

## Uninstall

```bash
sudo systemctl disable --now ktemata-ai-ingest.timer
sudo rm -f /etc/systemd/system/ktemata-ai-ingest.{service,timer}
sudo rm -f /etc/systemd/system/ktemata-ai-zim-index@.service
sudo systemctl daemon-reload
sudo rm -f /usr/local/bin/ktemata-ai /etc/ktemata/ai.conf
sudo rm -rf /var/lib/ktemata-ai /opt/ktemata-ai
# optional: remove Ollama itself
sudo systemctl disable --now ollama
```

ZIM indexes live beside the archives as `<stem>_<hash>_rag_index/`; remove them with the archives
or delete those directories explicitly. The old `llm`/`llm-tools-kiwix` venv is not used by this
version; if `/usr/local/bin/llm` points at `/opt/ktemata-ai/venv/bin/llm`, remove the symlink and
the old venv.

## Credits

ZIM retrieval uses [KiwixRAG](https://github.com/brunuff/KiwixRAG) by brunuff, cloned at install
time. Its upstream README describes the project as work in progress. The chunker, BGE
embeddings and Chroma store remain upstream's; Ktemata adds direct `zimdump` enumeration, the
metadata writer, the headless query wrapper, the CLI, the on-demand systemd unit, and the admin
controls.

The document index, prompts, CLI and admin integration are part of Ktemata.

## Verified

The document CLI and admin **Ask the library** box were exercised against a fake Ollama endpoint
and headless Chromium. The **AI index** column and **Ask ZIM** form were driven in headless
Chromium against a fake `ktemata-ai`/`systemctl` with a sample archive, including the per-row
Build/Rebuild controls and ZIM answer sources. The KiwixRAG path was exercised on Debian 13 arm64
with a venv containing `sentence-transformers`, `chromadb` and `torch`. With the 4.4 MB `wikiciv`
sample and `--limit 3`, the wrapper indexed 3 articles / 10 chunks; the query
`What is an abacus?` returned the Abacus article. `zim-ask` was then exercised end-to-end with a
fake Ollama endpoint and the real Chroma index. The installer dry run was checked in Debian 13.
Real 3B model latency on the Pi is not benchmarked in this repository; the numbers above are
expectations, not measurements.
