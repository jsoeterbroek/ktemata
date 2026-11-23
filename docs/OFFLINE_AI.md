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

**ZIM is not indexed automatically.** A `.zim` file is a compressed archive with its own index;
ingesting all of Wikipedia as chunks is not practical on a Pi. For large archives use `zim-ask`,
which searches Kiwix's own index directly — see
[ZIM direct search](#zim-direct-search-llm-tools-kiwix). `zim-ingest` remains available when you
want a curated vector slice — see [ZIM ingestion](#zim-ingestion).

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

1. installs `python3-numpy`, `python3-venv`, `python3-pip`, `poppler-utils`, `zim-tools`, `curl`,
   `ca-certificates`, `zstd`;
2. installs Ollama with the official installer if `ollama` is absent, and enables
   `ollama.service`;
3. pulls the embedding and generation models through Ollama's API (skip with `--no-models`);
4. installs `/usr/local/bin/ktemata-ai` and `/etc/ktemata/ai.conf`;
5. installs `llm`, `llm-ollama` and `llm-tools-kiwix` in `/opt/ktemata-ai/venv`, pinning
   `libzim<4` because the plugin's search API breaks with libzim 4.x;
6. adds `export KIWIX_HOME="..."` to the shell user's `~/.bashrc` (`--shell-user`, default: the
   sudo user, else `ktemata`);
7. updates the library admin UI and server with the **Ask the library** box and restarts
   `ktemata-admin.service` if it is installed;
8. runs the first `ktemata-ai ingest` (skip with `--no-ingest`);
9. installs and enables `ktemata-ai-ingest.timer` for a re-index every six hours.

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
ktemata-ai zim-ask "How do I install Gentoo?"   # Kiwix's own index, no vector build
```

`ingest` hashes each file and only embeds changed content. `--root DIR` overrides the configured
roots for one run; `--limit N` bounds a first test.

### ZIM ingestion

`zim-ingest` extracts selected articles from a ZIM with `zimdump`, writes them as HTML under
`/var/lib/kiwix/zim-text`, and indexes them. The extraction is deliberately bounded; it is not a
way to ingest an entire Wikipedia archive.

```bash
# 200 articles from namespace A, then index them
sudo ktemata-ai zim-ingest --zim /srv/kiwix/zim/your-file.zim --limit 200

# only articles whose URL starts with Ab or Ac
sudo ktemata-ai zim-ingest --zim /srv/kiwix/zim/your-file.zim \
    --prefix Ab --prefix Ac --limit 50

# see what would be selected, write nothing
ktemata-ai zim-ingest --zim /srv/kiwix/zim/your-file.zim --limit 20 --dry-run

# extract only; run ktemata-ai ingest later
sudo ktemata-ai zim-ingest --zim /srv/kiwix/zim/your-file.zim --limit 20 --extract-only
```

| Option | Meaning |
|---|---|
| `--zim FILE` | ZIM to read; repeatable |
| `--limit N` | articles per ZIM, default 200 |
| `--prefix TEXT` | keep URLs starting with TEXT; repeatable |
| `--ns N` | ZIM namespace, default `A` (articles) |
| `--out DIR` | staging directory, default `/var/lib/kiwix/zim-text` |
| `--extract-only` | extract without indexing |
| `--dry-run` | list selected URLs, write nothing |

The per-ZIM staging directory is removed before re-extraction, so lowering `--limit` removes the
old extra articles from the next ingest. The default staging directory is under `/var/lib/kiwix`
and is therefore already one of the normal ingest roots; a custom `--out` is added for that run.
Run it as root because it writes the library and the index.

Start with a small `--limit` and check `ktemata-ai status`; a 200-article slice is a useful test,
a full `maxi` archive is not.

The index is `/var/lib/ktemata-ai/index.sqlite3`, owned by root and readable by all (`0644`). The
text itself is therefore readable by any local user; the source documents already are.

### From the library admin

`http://<device>:8081/` has an **Ask the library** box in the Library panel, between the Library
heading and the archive table. The installer also adds a **Ktemata Admin** desktop icon for this
page. It calls
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
- The ZIM direct-search venv is installed from PyPI at install time. At runtime `llm` only talks
  to the local Ollama server and reads the ZIM files; it adds no listening service.
- The admin page is authenticated; the AI route is under the same auth.
- The ingest service runs as root because it reads the library and writes the index. It is
  `ProtectSystem=strict` with only the index directory writable.
- The model can be wrong. The prompt restricts it to the retrieved sources and prints them; always
  check the cited path for a factual answer.
- This is retrieval over documents; ZIM archives are only included through the bounded
  `zim-ingest` extraction. Large PDFs and OCR-free scans produce poor text.

## Uninstall

```bash
sudo systemctl disable --now ktemata-ai-ingest.timer
sudo rm -f /etc/systemd/system/ktemata-ai-ingest.{service,timer}
sudo systemctl daemon-reload
sudo rm -f /usr/local/bin/ktemata-ai /etc/ktemata/ai.conf
if [ "$(readlink -f /usr/local/bin/llm 2>/dev/null)" = /opt/ktemata-ai/venv/bin/llm ]; then
    sudo rm -f /usr/local/bin/llm
fi
sudo rm -rf /var/lib/ktemata-ai /opt/ktemata-ai
# optional: remove Ollama itself
sudo systemctl disable --now ollama
```

## Verified

The CLI was exercised against a fake Ollama endpoint: text/Markdown/HTML/EPUB/DOCX extraction,
chunking, embedding, incremental re-index, pruning, `search`, `ask --json`, and `status --json`.
The bounded ZIM extractor was exercised against the 4.4 MB `wikiciv` sample: dry-run, a URL prefix,
extraction, cleaning on re-run, and a full ingest (3 articles, 10 chunks). The installer's dry run
was checked in Debian 13, and the generated config/service/timer were inspected. The admin
**Ask the library** box was driven in headless Chromium against a fake `ktemata-ai`: status,
question, answer and sources rendered, and the box stayed disabled for a missing index/model. The
real 3B model has not been benchmarked on the Pi in this repository; the numbers above are
expectations, not measurements.


## ZIM direct search (llm-tools-kiwix)

ZIM archives already carry a Xapian full-text index. For large archives, use that index directly
instead of building a vector database. The AI calls `kiwix_search_and_collect`, reads up to three
matching articles, and answers from that content. There is no pre-indexing step and the RAM cost
is essentially the model.

This is the recommended ZIM path on a Pi; `zim-ingest` (above) is only for bounded vector slices.

### Install

The offline AI installer creates a dedicated venv and installs the LLM CLI, its Ollama plugin,
and the Kiwix tools plugin:

```bash
sudo ./work/scripts/post-install-ai.sh --yes
```

That installs `llm`, `llm-ollama` and `llm-tools-kiwix` in `/opt/ktemata-ai/venv`, with
`libzim<4` pinned (`llm-tools-kiwix` 0.1 uses the libzim 3.x search API; 4.x returns no matches).
It also links `/usr/local/bin/llm` to the venv when that path is free, so `llm` works without
activating the venv.

The installer writes a marked block to the shell user's `~/.bashrc`:

```bash
# >>> ktemata offline AI >>>
# Used by llm-tools-kiwix; remove this block to manage KIWIX_HOME yourself.
export KIWIX_HOME=/srv/kiwix/zim
# <<< ktemata offline AI <<<
```

Open a new shell or `source ~/.bashrc` to pick it up. The block is replaced on re-runs, so it never
duplicates; use `--shell-user NAME` to choose the account (default: the sudo user, else `ktemata`).
This assumes bash, the Pi OS default; for zsh add the same `export KIWIX_HOME=...` to `~/.zshrc`.
The ZIM directory defaults to `/srv/kiwix/zim`; override it with `--zim-home DIR` or by editing
`/etc/ktemata/ai.conf`.

### Use

```bash
ktemata-ai zim-ask "How do I install Gentoo?"
ktemata-ai zim-ask --zim /srv/kiwix/zim/gentoo_en_all_maxi_2021-03.zim "How do I install Gentoo?"
ktemata-ai zim-ask --json "..."       # {answer, model, zim, zims}
```

The wrapper runs the plugin's `kiwix_search_and_collect` tool through the LLM CLI. You can also run
it directly:

```bash
KIWIX_HOME=/srv/kiwix/zim OLLAMA_HOST=http://127.0.0.1:11434 \
  /opt/ktemata-ai/venv/bin/llm -m ollama/qwen2.5:3b \
  -T kiwix_search_and_collect -n \
  "How do I install Gentoo?"
```

`llm tools list` shows the three registered tools and the ZIM files the plugin discovered:

```bash
KIWIX_HOME=/srv/kiwix/zim llm tools list
```

If `/usr/local/bin/llm` was occupied, use `/opt/ktemata-ai/venv/bin/llm` instead. The plugin
searches `KIWIX_HOME/*.zim` (flat, not recursive) and also the current directory. The model
receives the list in the tool description and selects the archive; `--zim` narrows the request to
one file in the prompt. `-n` keeps the query out of `llm`'s SQLite log.

### Models

`AI_ZIM_MODEL` selects the model for this path; it defaults to `AI_MODEL`. **Tool calling is
required**, and Qwen 2.5 3B is the recommendation for a 4–8 GB Pi:

```bash
sudo ./work/scripts/post-install-ai.sh --yes --zim-model qwen2.5:3b
# or on an existing install:
ollama pull qwen2.5:3b
sudo sed -i 's/^AI_ZIM_MODEL=.*/AI_ZIM_MODEL=qwen2.5:3b/' /etc/ktemata/ai.conf
```

With an existing `/etc/ktemata/ai.conf`, existing keys win over the installer flags; missing ZIM
keys are appended on the next installer run. Edit the file to change a value.

| Key | Meaning |
|---|---|
| `AI_ZIM_MODEL` | tool-calling model for `zim-ask` (default: `AI_MODEL`) |
| `AI_ZIM_HOME` | directory scanned for `*.zim` (default `/srv/kiwix/zim`) |

`ktemata-ai status` prints the ZIM archive count, the model and whether the `llm` venv is ready.

### Why not KiwixRAG or a full vector index?

`KiwixRAG` (brunuff) is a work-in-progress chat application built around sentence-transformers
and ChromaDB; it builds a vector index and its README warns that indexing can take hours. That is
the heavy path this design avoids. `zim-llm` similarly vectorises ZIMs and is reasonable only for
small, specialised archives. `llm-tools-kiwix` is a single small plugin that uses Kiwix's existing
Xapian index, so the CPU and storage cost stays at model inference and the articles you actually
read.

The normal `zim-ingest` command remains for curated slices you want in the document index; it is
not the ZIM search path.

### Limits

- The plugin returns at most three matching articles per tool call, so very broad questions read
  only the top results.
- The model must support tool calling. If it does not, `llm` reports a tool/schema error; switch
  `AI_ZIM_MODEL` to Qwen 2.5 3B or another tool-capable model.
- The tool description lists every ZIM in the directory. Keep the directory focused, or use
  `--zim` to point at one archive.
- The answer quality depends on the model and the ZIM's own index; verify citations in the answer
  against `kiwix-serve` on `:8080`.
- This path is CLI-only. The admin **Ask the library** box uses the document index; ask ZIM
  questions with `ktemata-ai zim-ask` over SSH or a terminal.

### Verified

The `llm-tools-kiwix` venv was installed on Debian 13 arm64 (`llm 0.38`, `libzim 3.13.1`,
`llm-tools-kiwix 0.1`, `llm-ollama 0.20`), and `llm tools list` registered
`kiwix_search_and_collect`, `kiwix_search` and `kiwix_read`. With `libzim<4`, the plugin's search
returned 2 articles for `Abacus` and 3 for `arithmetic` from the `wikiciv` sample; with libzim
4.1.0 it returned none, which is why the installer pins `<4`. The `zim-ask` wrapper was exercised
with a fake `llm` binary, including `--zim` and `--json`; a real model-driven tool call has not
been run on the Pi in this repository.
