# Offline AI

Ktemata can answer questions from its own documents without an internet connection. The stack is
deliberately small:

- **Ollama** runs a quantised instruction model on the Pi and listens on `127.0.0.1:11434`.
- **ktemata-ai** extracts text from documents, chunks it, embeds the chunks with a small embedding
  model, and stores them in a SQLite index.
- `ask` embeds the question, retrieves the closest chunks, and asks the model to answer from those
  chunks only. Sources are printed with every answer.

Nothing is exposed on the LAN. There is no AI web service of its own: the CLI is local, and the
existing library admin on `:8081` gains an **Ask the library** box when the CLI and an index exist.

This is a separate install step because it downloads models and changes the memory/thermal profile
of the box. The base [`post-install.sh`](POST_INSTALL.md) stays the same unless you pass `--ai`.

## What gets read

The default roots are:

```
/var/lib/kiwix          # Kiwix state and any documents you put here
/srv/kiwix/zim          # the ZIM library directory
```

`/var/lib/kiwix` is included first, as requested. Text is extracted recursively from:

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

**ZIM is not a document format for this pipeline.** A `.zim` file is a compressed archive with its
own index; ingesting all of Wikipedia as chunks is not practical on a Pi and is deliberately out of
scope. ZIM files are skipped. If you want a ZIM's text in the AI, extract the articles you care
about (`zimdump`) into text/HTML under one of the roots first.

## Hardware and expectations

A Pi 5 with **8 GB** is the reference. Defaults:

| Component | Default | Approx. download | Memory |
|---|---|---|---|
| generation model | `llama3.2:3b` (Q4) | ~2 GB | ~2.5 GB |
| embeddings | `nomic-embed-text` | ~274 MB | ~0.5 GB |
| index | SQLite in `/var/lib/ktemata-ai/` | — | grows with text |

Expect a few tokens per second on CPU. `--model llama3.2:1b` is noticeably faster and weaker;
`qwen2.5:3b` is another 3B option. Model inference is the hot path: the Pi will warm up, and
continuous questions will throttle sooner than reading a book. Ollama keeps a model resident for a
few minutes after a request; that is the memory peak.

The model files live in Ollama's store (`/usr/share/ollama/.ollama/models` for the service). Plan
for roughly 3 GB of free space before the index.

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
sudo ./work/scripts/post-install-ai.sh --no-models --no-ingest     # fully offline, preloaded
sudo ./work/scripts/post-install-ai.sh --no-service                # no 6-hour timer
sudo ./work/scripts/post-install-ai.sh --ingest-dir /srv/docs       # repeatable
./work/scripts/post-install-ai.sh --dry-run                         # no root, no changes
```

What it does:

1. installs `python3-numpy`, `poppler-utils`, `curl`, `ca-certificates`, `zstd`;
2. installs Ollama with the official installer if `ollama` is absent, and enables
   `ollama.service`;
3. pulls the embedding and generation models through Ollama's API (skip with `--no-models`);
4. installs `/usr/local/bin/ktemata-ai` and `/etc/ktemata/ai.conf`;
5. updates the library admin UI with the **Ask the library** box if the admin is installed;
6. runs the first `ktemata-ai ingest` (skip with `--no-ingest`);
7. installs and enables `ktemata-ai-ingest.timer` for a re-index every six hours.

A re-run is idempotent. An existing `/etc/ktemata/ai.conf` is the source of truth: the installer
uses its models and roots instead of the flags, and never overwrites it. Edit the file to change
them.

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
```

| Key | Meaning |
|---|---|
| `AI_MODEL` | Ollama model used to answer |
| `AI_EMBED_MODEL` | Ollama embedding model; changing it requires `ingest --force` |
| `AI_OLLAMA_URL` | API endpoint, localhost by default |
| `AI_INGEST_DIRS` | space-separated roots; paths must not contain spaces |
| `AI_DB` | SQLite index |
| `AI_CHUNK_CHARS` | target chunk size in characters |
| `AI_CHUNK_OVERLAP` | overlap for long paragraphs |
| `AI_TOP_K` | chunks retrieved per question |
| `AI_MAX_FILE_MB` | skip larger files |

The file is sourced by the installer when it exists, so keep it root-owned and not writable by
group/other (`chmod 644`, `chown root:root`).

## Use

```bash
ktemata-ai status                 # model, document/chunk counts, last ingest, Ollama state
ktemata-ai ingest                 # add/update changed files, prune deleted ones
sudo ktemata-ai ingest --force    # re-embed everything
ktemata-ai search "keyword"       # show the closest chunks without the model
ktemata-ai ask "What does the manual say about charging?"
ktemata-ai ask "..." --json       # {answer, sources, model}
```

`ingest` hashes each file and only embeds changed content. `--root DIR` overrides the configured
roots for one run; `--limit N` bounds a first test.

The index is `/var/lib/ktemata-ai/index.sqlite3`, owned by root and readable by all (`0644`). The
text itself is therefore readable by any local user; the source documents already are.

### From the library admin

`http://<device>:8081/` has an **Ask the library** box below the archive table. It calls
`ktemata-ai ask --json` as root, shows the answer, and lists the source paths/chunks. The box stays
disabled until the index contains chunks, Ollama is reachable, and both the generation and embedding
models are present; otherwise its status line says what is missing. The admin service needs no
restart after installing the AI; the route checks for the CLI each time.

The admin page is protected by HTTP Basic auth, but there is no TLS. Keep it on the hotspot or a
trusted LAN, or bind it to loopback and use an SSH tunnel.

## Re-indexing

The timer runs the service at boot + 5 minutes and every 6 hours:

```bash
systemctl list-timers ktemata-ai-ingest.timer
systemctl status ktemata-ai-ingest
journalctl -u ktemata-ai-ingest -f
sudo systemctl start ktemata-ai-ingest     # index now
```

A large first index can take a while; the service has a one-hour start timeout. Re-run
`ktemata-ai ingest` by hand to see progress.

## Offline models

`--no-models` skips the download. To move models to an isolated box, pull them on a connected
machine with the same Ollama version, then copy the model store:

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

Then run the installer with `--no-models` (and `--no-ingest` if you want to start the index later),
or just `sudo ktemata-ai ingest`.

## Security and limits

- Ollama binds `127.0.0.1`; no API port is opened on the LAN.
- The admin page is authenticated; the AI route is under the same auth.
- The ingest service runs as root because it reads the library and writes the index. It is
  `ProtectSystem=strict` with only the index directory writable.
- The model can be wrong. The prompt restricts it to the retrieved sources and prints them; always
  check the cited path for a factual answer.
- This is retrieval over documents, not a search engine for ZIM archives. Large PDFs and OCR-free
  scans produce poor text.

## Uninstall

```bash
sudo systemctl disable --now ktemata-ai-ingest.timer
sudo rm -f /etc/systemd/system/ktemata-ai-ingest.{service,timer}
sudo systemctl daemon-reload
sudo rm -f /usr/local/bin/ktemata-ai /etc/ktemata/ai.conf
sudo rm -rf /var/lib/ktemata-ai
# optional: remove Ollama itself
sudo systemctl disable --now ollama
```

## Verified

The CLI was exercised against a fake Ollama endpoint: text/Markdown/HTML/EPUB/DOCX extraction,
chunking, embedding, incremental re-index, pruning, `search`, `ask --json`, and `status --json`.
The installer's dry run was checked in Debian 13, and the generated config/service/timer were
inspected. The admin **Ask the library** box was driven in headless Chromium against a fake
`ktemata-ai`: status, question, answer and sources rendered, and the box stayed disabled for a
missing index/model. The real 3B model has not been benchmarked on the Pi in this repository; the
numbers above are expectations, not measurements.
