#!/usr/bin/env python3
"""Ktemata library admin: a small web UI for the ZIM library and kiwix-serve.

The device itself runs the kiosk; this is the maintenance page you open from a laptop on
the same network (or over the hotspot) to add, inspect and remove archives.

  python3 work/scripts/ktemata-admin.py --zim-dir /srv/kiwix/zim --auth-file /etc/ktemata/admin.conf

Nothing here needs a third-party package: http.server, JSON and subprocess cover it, which
keeps the appliance free of a web framework to patch.

WHAT THE PAGE CAN DO
  list      archives with size, mtime and whether the current index knows them
  upload    resumable chunked upload straight into the library directory
  delete    remove an archive (and discard an interrupted upload)
  service   start, stop and restart kiwix.service, show its state
  reindex   rebuild library.xml with kiwix-library, then restart kiwix-serve
  storage   filesystem use and the share taken by ZIM files

SAFETY
  - HTTP Basic auth from --auth-file; without one the server refuses to bind beyond
    loopback, because these endpoints can destroy the library.
  - Mutations require the X-Ktemata header and a same-origin Origin, so a random web page
    cannot drive them with a form or a no-cors fetch.
  - Names cannot contain a path separator; downloads and deletes resolve inside the
    library directory only.
  - Uploads land in <name>.part and are renamed only after the last chunk, so a half
    archive is never served or indexed. The first four bytes must be a ZIM header.
  - Plain HTTP: the password crosses the LAN in the clear. Use --bind 127.0.0.1 and an SSH
    tunnel when the network is not trusted.
"""

import argparse
import base64
import grp
import hmac
import json
import os
import shutil
import subprocess
import sys
import threading
import time
import xml.etree.ElementTree as ET
from http import HTTPStatus
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from urllib.parse import parse_qs, quote, urlparse

VERSION = "0.1.0"

DEFAULT_ZIM_DIR = "/srv/kiwix/zim"
DEFAULT_STATE_DIR = "/var/lib/kiwix"
DEFAULT_SERVICE = "kiwix"
DEFAULT_LIBRARY_HELPER = "/usr/local/bin/kiwix-library"
DEFAULT_AUTH_FILE = "/etc/ktemata/admin.conf"
DEFAULT_LIBRARY_PORT = 8080
DEFAULT_PORT = 8081
DEFAULT_AI_CLI = "/usr/local/bin/ktemata-ai"

# One chunk: small enough for a flaky link, large enough that the request overhead vanishes.
MAX_CHUNK = 64 * 1024 * 1024
COPY_BUFFER = 1024 * 1024
ZIM_MAGIC = b"ZIM\x04"
SERVICE_ACTIONS = ("start", "stop", "restart")

ASSETS = {
    "/": ("index.html", "text/html; charset=utf-8"),
    "/index.html": ("index.html", "text/html; charset=utf-8"),
    "/style.css": ("style.css", "text/css; charset=utf-8"),
    "/app.js": ("app.js", "text/javascript; charset=utf-8"),
    "/favicon.svg": ("favicon.svg", "image/svg+xml"),
}

CSP = (
    "default-src 'self'; img-src 'self' data:; style-src 'self'; script-src 'self'; "
    "connect-src 'self'; base-uri 'none'; frame-ancestors 'none'"
)


# --------------------------------------------------------------------------- configuration
class Config:
    def __init__(self, args):
        self.zim_dir = os.path.abspath(args.zim_dir)
        self.state_dir = os.path.abspath(args.state_dir)
        self.library_xml = os.path.join(self.state_dir, "library.xml")
        self.helper = args.library_helper
        self.service = args.service
        self.port = args.port
        self.library_port = args.library_port
        self.assets = find_assets(args.assets)
        self.user, self.password = load_credentials(args.auth_file, args.auth_user, args.auth_password)
        self.bind = args.bind or ("0.0.0.0" if self.password else "127.0.0.1")
        self.auth_enabled = bool(self.password)


def find_assets(explicit):
    here = os.path.dirname(os.path.realpath(__file__))
    candidates = [explicit] if explicit else []
    candidates += [os.path.join(here, "ktemata-admin"), "/usr/share/ktemata/admin"]
    for path in candidates:
        if path and os.path.isfile(os.path.join(path, "index.html")):
            return os.path.abspath(path)
    raise SystemExit("ktemata-admin: web assets not found (pass --assets DIR)")


def parse_config(path):
    values = {}
    with open(path, encoding="utf-8") as fh:
        for line in fh:
            line = line.strip()
            if not line or line.startswith("#") or "=" not in line:
                continue
            key, value = line.split("=", 1)
            values[key.strip()] = value.strip().strip('"').strip("'")
    return values


def load_credentials(auth_file, user, password):
    """Password resolution: explicit args, then --auth-file, then the installer's default file."""
    if password:
        return (user or "ktemata"), password
    path = auth_file or (DEFAULT_AUTH_FILE if os.path.isfile(DEFAULT_AUTH_FILE) else None)
    if not path:
        return None, None
    try:
        values = parse_config(path)
    except OSError as exc:
        raise SystemExit(f"ktemata-admin: cannot read {path}: {exc}")
    return (
        values.get("KTEMATA_ADMIN_USER") or values.get("USER") or "ktemata",
        values.get("KTEMATA_ADMIN_PASSWORD") or values.get("PASSWORD") or None,
    )


# --------------------------------------------------------------------------- library state
def valid_name(name):
    if not name or len(name) > 200 or name.startswith("."):
        return False
    if name != os.path.basename(name) or "/" in name or "\\" in name:
        return False
    # kiwix-library and kiwix-serve match the lowercase suffix; do not accept a name the index
    # can never pick up.
    if not name.endswith(".zim"):
        return False
    return not any(ord(ch) < 32 or ord(ch) == 127 for ch in name)


def zim_path(cfg, name):
    if not valid_name(name):
        raise AdminError(HTTPStatus.BAD_REQUEST, "invalid ZIM file name")
    path = os.path.join(cfg.zim_dir, name)
    # Belt and braces: the basename check already rules out traversal.
    if os.path.dirname(os.path.realpath(path)) != os.path.realpath(cfg.zim_dir):
        raise AdminError(HTTPStatus.BAD_REQUEST, "invalid ZIM file name")
    return path


def group_gid(name):
    try:
        return grp.getgrnam(name).gr_gid
    except KeyError:
        return None


class AdminError(Exception):
    def __init__(self, status, message):
        super().__init__(message)
        self.status = status
        self.message = message


def systemctl(*args, timeout=30):
    binary = shutil.which("systemctl")
    if not binary:
        raise AdminError(HTTPStatus.SERVICE_UNAVAILABLE, "systemctl is not available on this host")
    try:
        return subprocess.run(
            [binary, *args],
            check=False,
            capture_output=True,
            text=True,
            errors="replace",
            timeout=timeout,
        )
    except subprocess.TimeoutExpired:
        raise AdminError(HTTPStatus.GATEWAY_TIMEOUT, f"systemctl {' '.join(args)} timed out")


def ai_command(args, timeout=110):
    """Run ktemata-ai as root and return its JSON. It is installed separately."""
    binary = os.environ.get("KTEMATA_AI_CLI", DEFAULT_AI_CLI)
    if not os.path.isfile(binary):
        raise AdminError(
            HTTPStatus.SERVICE_UNAVAILABLE,
            "offline AI is not installed; run post-install-ai.sh",
        )
    try:
        result = subprocess.run(
            [binary, *args],
            check=False,
            capture_output=True,
            text=True,
            errors="replace",
            timeout=timeout,
        )
    except subprocess.TimeoutExpired:
        raise AdminError(HTTPStatus.GATEWAY_TIMEOUT, "offline AI timed out")
    except OSError as exc:
        raise AdminError(HTTPStatus.SERVICE_UNAVAILABLE, f"offline AI is not available: {exc}")
    if result.returncode != 0:
        lines = (result.stderr or result.stdout).strip().splitlines()
        message = lines[-1] if lines else f"ktemata-ai exited {result.returncode}"
        raise AdminError(HTTPStatus.SERVICE_UNAVAILABLE, message)
    try:
        return json.loads(result.stdout)
    except ValueError:
        raise AdminError(HTTPStatus.INTERNAL_SERVER_ERROR, "offline AI returned invalid JSON")


def ai_status():
    if not os.path.isfile(os.environ.get("KTEMATA_AI_CLI", DEFAULT_AI_CLI)):
        return {"installed": False}
    try:
        return ai_command(["status", "--json"], timeout=30)
    except AdminError as exc:
        return {"installed": True, "error": exc.message}


def service_state(cfg):
    state = {
        "name": cfg.service,
        "available": bool(shutil.which("systemctl")),
        "active": "unknown",
        "sub": "",
        "enabled": "",
        "load": "",
        "since": "",
        "restarts": "",
        "port": cfg.library_port,
    }
    if not state["available"]:
        return state
    try:
        proc = systemctl(
            "show",
            "--no-pager",
            "--property=ActiveState,SubState,UnitFileState,LoadState,ActiveEnterTimestamp,NRestarts",
            cfg.service,
        )
    except AdminError as exc:
        state["error"] = exc.message
        return state
    values = {}
    for line in proc.stdout.splitlines():
        key, _, value = line.partition("=")
        values[key] = value.strip()
    state["active"] = values.get("ActiveState") or "unknown"
    state["sub"] = values.get("SubState", "")
    state["enabled"] = values.get("UnitFileState", "")
    state["load"] = values.get("LoadState", "")
    state["since"] = values.get("ActiveEnterTimestamp", "")
    state["restarts"] = values.get("NRestarts", "")
    return state


def library_paths(root):
    """Basenames recorded in kiwix-manage's XML. Current kiwix-tools writes <book> elements;
    older files use <archive>, so accept both."""
    entries = root.findall("book") + root.findall("archive")
    return {os.path.basename(entry.get("path", "")) for entry in entries}


def index_state(cfg, names):
    info = {
        "xml": cfg.library_xml,
        "exists": os.path.isfile(cfg.library_xml),
        "mtime": 0,
        "archives": 0,
        "stale": False,
        "missing": [],
        "gone": [],
        "error": "",
    }
    if not info["exists"]:
        return info
    try:
        info["mtime"] = int(os.path.getmtime(cfg.library_xml))
        root = ET.parse(cfg.library_xml).getroot()
    except (OSError, ET.ParseError) as exc:
        info["error"] = str(exc)
        return info
    indexed = library_paths(root)
    info["archives"] = len(indexed)
    info["missing"] = sorted(names - indexed)
    info["gone"] = sorted(indexed - names)
    info["stale"] = bool(info["missing"] or info["gone"])
    return info


def disk_state(cfg, zim_bytes):
    sv = os.statvfs(cfg.zim_dir)
    total = sv.f_blocks * sv.f_frsize
    free = sv.f_bavail * sv.f_frsize
    used = total - sv.f_bfree * sv.f_frsize
    return {
        "total": total,
        "used": used,
        "free": free,
        "percent": round(used * 100.0 / total, 1) if total else 0.0,
        "zim_bytes": zim_bytes,
    }


def build_state(cfg):
    zims, parts = [], []
    indexed = set()
    try:
        root = ET.parse(cfg.library_xml).getroot()
        indexed = library_paths(root)
    except (OSError, ET.ParseError, AttributeError):
        pass

    with os.scandir(cfg.zim_dir) as entries:
        for entry in entries:
            try:
                if not entry.is_file():
                    continue
                st = entry.stat()
            except OSError:
                continue
            if entry.name.endswith(".zim"):
                zims.append(
                    {
                        "name": entry.name,
                        "size": st.st_size,
                        "mtime": int(st.st_mtime),
                        "indexed": entry.name in indexed,
                    }
                )
            elif entry.name.endswith(".zim.part"):
                parts.append(
                    {
                        "name": entry.name[: -len(".part")],
                        "size": st.st_size,
                        "mtime": int(st.st_mtime),
                    }
                )
    zims.sort(key=lambda z: z["name"].lower())
    parts.sort(key=lambda p: p["name"].lower())
    names = {z["name"] for z in zims}
    return {
        "version": VERSION,
        "zim_dir": cfg.zim_dir,
        "zims": zims,
        "parts": parts,
        "disk": disk_state(cfg, sum(z["size"] for z in zims)),
        "service": service_state(cfg),
        "index": index_state(cfg, names),
        "library_port": cfg.library_port,
    }


# --------------------------------------------------------------------------- mutations
class Library:
    """Serialises index rebuilds and per-name uploads; the filesystem is shared state."""

    def __init__(self, cfg):
        self.cfg = cfg
        self._index = threading.Lock()
        self._uploads = {}
        self._uploads_lock = threading.Lock()
        self._chown_gid = group_gid(cfg.service)

    def upload_lock(self, name):
        with self._uploads_lock:
            return self._uploads.setdefault(name, threading.Lock())

    def reindex(self):
        if not self._index.acquire(blocking=False):
            raise AdminError(HTTPStatus.CONFLICT, "an index rebuild is already running")
        try:
            if not os.path.isfile(self.cfg.helper):
                raise AdminError(
                    HTTPStatus.SERVICE_UNAVAILABLE,
                    f"{self.cfg.helper} not found; install it with post-install.sh",
                )
            try:
                proc = subprocess.run(
                    [self.cfg.helper, self.cfg.zim_dir, self.cfg.library_xml],
                    check=False,
                    capture_output=True,
                    text=True,
                    errors="replace",
                    timeout=1800,
                )
            except subprocess.TimeoutExpired:
                raise AdminError(HTTPStatus.GATEWAY_TIMEOUT, "index rebuild timed out after 30 min")
            output = (proc.stdout + proc.stderr).strip()
            if proc.returncode != 0:
                raise AdminError(
                    HTTPStatus.INTERNAL_SERVER_ERROR,
                    f"kiwix-library exited {proc.returncode}: {output or 'no output'}",
                )
            return output
        finally:
            self._index.release()

    def service(self, action):
        if action not in SERVICE_ACTIONS:
            raise AdminError(HTTPStatus.BAD_REQUEST, f"action must be one of {', '.join(SERVICE_ACTIONS)}")
        proc = systemctl(action, f"{self.cfg.service}.service", timeout=120)
        output = (proc.stdout + proc.stderr).strip()
        if proc.returncode != 0:
            raise AdminError(
                HTTPStatus.INTERNAL_SERVER_ERROR,
                f"systemctl {action} failed: {output or 'no output'}",
            )
        # The unit exits immediately when there is nothing to serve; report that as it is.
        return output

    def finish(self, part, dest):
        size = os.path.getsize(part)
        try:
            with open(part, "rb") as fh:
                magic = fh.read(4)
        except OSError as exc:
            raise AdminError(HTTPStatus.INTERNAL_SERVER_ERROR, f"cannot read upload: {exc}")
        if magic != ZIM_MAGIC:
            os.unlink(part)
            raise AdminError(HTTPStatus.UNSUPPORTED_MEDIA_TYPE, "not a ZIM archive (bad magic)")
        os.chmod(part, 0o644)
        if self._chown_gid is not None and os.geteuid() == 0:
            try:
                os.chown(part, -1, self._chown_gid)
            except OSError:
                pass
        os.replace(part, dest)
        return size


# --------------------------------------------------------------------------- HTTP
class Handler(BaseHTTPRequestHandler):
    server_version = "ktemata-admin/" + VERSION
    sys_version = ""
    protocol_version = "HTTP/1.1"
    timeout = 120

    cfg = None
    library = None

    # -- plumbing ---------------------------------------------------------------------
    def log_message(self, fmt, *args):
        # Polling /api/state every few seconds would bury everything else in the journal.
        if getattr(self, "path", "").startswith("/api/state"):
            return
        stamp = time.strftime("%Y-%m-%d %H:%M:%S")
        sys.stderr.write(f"{stamp} {self.address_string()} {fmt % args}\n")

    def send_body(self, status, body, content_type="application/json; charset=utf-8", extra=None):
        self.send_response(status)
        self.send_header("Content-Type", content_type)
        self.send_header("Content-Length", str(len(body)))
        self.send_header("Cache-Control", "no-store")
        self.send_header("X-Content-Type-Options", "nosniff")
        self.send_header("Referrer-Policy", "no-referrer")
        for key, value in (extra or {}).items():
            self.send_header(key, value)
        self.end_headers()
        if self.command != "HEAD":
            self.wfile.write(body)

    def send_json(self, payload, status=HTTPStatus.OK):
        self.send_body(status, json.dumps(payload).encode("utf-8"), extra={"Content-Security-Policy": CSP})

    def fail(self, status, message):
        # A rejected request may not have consumed its body; never reuse that connection.
        if self.command in ("POST", "PUT", "DELETE"):
            self.close_connection = True
        self.send_json({"error": message}, status)

    def authorised(self):
        if not self.cfg.auth_enabled:
            return True
        header = self.headers.get("Authorization", "")
        if not header.startswith("Basic "):
            return False
        try:
            raw = base64.b64decode(header[6:].strip(), validate=True).decode("utf-8")
            user, _, password = raw.partition(":")
        except (ValueError, UnicodeDecodeError):
            return False
        ok_user = hmac.compare_digest(user.encode(), self.cfg.user.encode())
        ok_pass = hmac.compare_digest(password.encode(), self.cfg.password.encode())
        return ok_user and ok_pass

    def require_auth(self):
        if self.authorised():
            return True
        if self.command in ("POST", "PUT", "DELETE"):
            self.close_connection = True
        self.send_body(
            HTTPStatus.UNAUTHORIZED,
            b"authentication required\n",
            "text/plain; charset=utf-8",
            {"WWW-Authenticate": 'Basic realm="Ktemata library", charset="UTF-8"'},
        )
        return False

    def same_origin(self):
        origin = self.headers.get("Origin")
        if not origin:
            return True  # curl and other non-browser clients
        return urlparse(origin).netloc.lower() == self.headers.get("Host", "").lower()

    def require_mutation(self):
        if self.headers.get("X-Ktemata") != "1":
            raise AdminError(HTTPStatus.FORBIDDEN, "missing X-Ktemata header")
        if not self.same_origin():
            raise AdminError(HTTPStatus.FORBIDDEN, "cross-origin request refused")

    def body_json(self):
        length = int(self.headers.get("Content-Length") or 0)
        if length <= 0 or length > 64 * 1024:
            raise AdminError(HTTPStatus.BAD_REQUEST, "expected a small JSON body")
        try:
            return json.loads(self.rfile.read(length))
        except (ValueError, UnicodeDecodeError):
            raise AdminError(HTTPStatus.BAD_REQUEST, "malformed JSON body")

    def query_name(self):
        query = parse_qs(urlparse(self.path).query)
        name = (query.get("name") or [""])[0]
        if not valid_name(name):
            raise AdminError(HTTPStatus.BAD_REQUEST, "invalid ZIM file name")
        return name

    # -- routes -----------------------------------------------------------------------
    def do_HEAD(self):
        self.do_GET()

    def do_GET(self):
        if not self.require_auth():
            return
        try:
            path = urlparse(self.path).path
            if path in ASSETS:
                self.serve_asset(path)
            elif path == "/healthz":
                self.send_json({"ok": True, "version": VERSION})
            elif path == "/api/state":
                self.send_json(build_state(self.cfg))
            elif path == "/api/ai/status":
                self.send_json(ai_status())
            elif path == "/api/upload":
                self.upload_status()
            elif path == "/api/download":
                self.download()
            else:
                raise AdminError(HTTPStatus.NOT_FOUND, "not found")
        except AdminError as exc:
            self.fail(exc.status, exc.message)
        except Exception as exc:  # noqa: BLE001 - a bug must not take the server down
            self.log_message("unhandled: %r", exc)
            self.fail(HTTPStatus.INTERNAL_SERVER_ERROR, f"internal error: {exc}")

    def do_POST(self):
        if not self.require_auth():
            return
        try:
            self.require_mutation()
            path = urlparse(self.path).path
            if path == "/api/upload":
                self.upload_chunk()
            elif path == "/api/service":
                payload = self.body_json()
                action = str(payload.get("action", ""))
                output = self.library.service(action)
                self.send_json(
                    {"ok": True, "output": output, "service": service_state(self.cfg)},
                )
            elif path == "/api/reindex":
                payload = self.body_json()
                output = self.library.reindex()
                restart = ""
                if payload.get("restart", True):
                    try:
                        restart = self.library.service("restart")
                    except AdminError as exc:
                        restart = f"index rebuilt, restart failed: {exc.message}"
                self.send_json(
                    {
                        "ok": True,
                        "output": output,
                        "restart": restart,
                        "state": build_state(self.cfg),
                    }
                )
            elif path == "/api/ai/ask":
                payload = self.body_json()
                question = str(payload.get("question") or "").strip()
                if not question:
                    raise AdminError(HTTPStatus.BAD_REQUEST, "question is required")
                if len(question) > 2000:
                    raise AdminError(HTTPStatus.BAD_REQUEST, "question is too long (2000 characters)")
                self.send_json(ai_command(["ask", question, "--json"]))
            else:
                raise AdminError(HTTPStatus.NOT_FOUND, "not found")
        except AdminError as exc:
            self.fail(exc.status, exc.message)
        except Exception as exc:  # noqa: BLE001
            self.log_message("unhandled: %r", exc)
            self.fail(HTTPStatus.INTERNAL_SERVER_ERROR, f"internal error: {exc}")

    def do_DELETE(self):
        if not self.require_auth():
            return
        try:
            self.require_mutation()
            path = urlparse(self.path).path
            name = self.query_name()
            if path == "/api/zim":
                target = zim_path(self.cfg, name)
                try:
                    os.unlink(target)
                except FileNotFoundError:
                    raise AdminError(HTTPStatus.NOT_FOUND, f"{name} is not in the library")
                except OSError as exc:
                    raise AdminError(HTTPStatus.INTERNAL_SERVER_ERROR, f"cannot delete {name}: {exc}")
                self.log_message("deleted %s", name)
                self.send_json({"ok": True, "deleted": name})
            elif path == "/api/upload":
                part = zim_path(self.cfg, name) + ".part"
                try:
                    os.unlink(part)
                except FileNotFoundError:
                    raise AdminError(HTTPStatus.NOT_FOUND, "no interrupted upload for that name")
                except OSError as exc:
                    raise AdminError(HTTPStatus.INTERNAL_SERVER_ERROR, f"cannot discard upload: {exc}")
                try:
                    os.unlink(part + ".json")
                except OSError:
                    pass
                self.send_json({"ok": True, "discarded": name})
            else:
                raise AdminError(HTTPStatus.NOT_FOUND, "not found")
        except AdminError as exc:
            self.fail(exc.status, exc.message)
        except Exception as exc:  # noqa: BLE001
            self.log_message("unhandled: %r", exc)
            self.fail(HTTPStatus.INTERNAL_SERVER_ERROR, f"internal error: {exc}")

    # -- handlers ---------------------------------------------------------------------
    def serve_asset(self, path):
        filename, content_type = ASSETS[path]
        full = os.path.join(self.cfg.assets, filename)
        try:
            with open(full, "rb") as fh:
                body = fh.read()
        except OSError:
            raise AdminError(HTTPStatus.NOT_FOUND, "asset missing")
        extra = {}
        if content_type.startswith("text/html"):
            extra["Content-Security-Policy"] = CSP
        self.send_body(HTTPStatus.OK, body, content_type, extra)

    def download(self):
        name = self.query_name()
        target = zim_path(self.cfg, name)
        try:
            with open(target, "rb") as fh:
                size = os.fstat(fh.fileno()).st_size
                self.send_response(HTTPStatus.OK)
                self.send_header("Content-Type", "application/octet-stream")
                self.send_header("Content-Length", str(size))
                self.send_header(
                    "Content-Disposition", f"attachment; filename*=UTF-8''{quote_name(name)}"
                )
                self.send_header("Cache-Control", "no-store")
                self.end_headers()
                if self.command == "HEAD":
                    return
                try:
                    shutil.copyfileobj(fh, self.wfile, COPY_BUFFER)
                except (BrokenPipeError, ConnectionResetError):
                    self.close_connection = True
        except FileNotFoundError:
            raise AdminError(HTTPStatus.NOT_FOUND, "no such archive")
        except OSError as exc:
            raise AdminError(HTTPStatus.INTERNAL_SERVER_ERROR, f"cannot open {name}: {exc}")

    def upload_status(self):
        name = self.query_name()
        part = zim_path(self.cfg, name) + ".part"
        received = os.path.getsize(part) if os.path.exists(part) else 0
        self.send_json(
            {
                "name": name,
                "received": received,
                "complete": os.path.exists(os.path.join(self.cfg.zim_dir, name)),
            }
        )

    def upload_chunk(self):
        # The query string carries the name, so a non-ASCII file name never has to travel in a
        # header; X-Zim-Name stays for curl users.
        query = parse_qs(urlparse(self.path).query)
        name = (self.headers.get("X-Zim-Name") or (query.get("name") or [""])[0]).strip()
        if not valid_name(name):
            raise AdminError(HTTPStatus.BAD_REQUEST, "invalid ZIM file name")
        try:
            total = int(self.headers.get("X-Zim-Total", ""))
            offset = int(self.headers.get("X-Zim-Offset", ""))
            length = int(self.headers.get("Content-Length", ""))
        except ValueError:
            raise AdminError(HTTPStatus.BAD_REQUEST, "X-Zim-Total, X-Zim-Offset and Content-Length are required")
        if total <= 0 or offset < 0 or length <= 0 or offset + length > total:
            raise AdminError(HTTPStatus.BAD_REQUEST, "inconsistent upload offsets")
        if length > MAX_CHUNK:
            raise AdminError(HTTPStatus.REQUEST_ENTITY_TOO_LARGE, f"chunk larger than {MAX_CHUNK} bytes")
        reset = self.headers.get("X-Zim-Reset") == "1"
        overwrite = self.headers.get("X-Zim-Overwrite") == "1"
        # Identity of the local file, so a resume cannot glue this head onto another archive's
        # body. Both headers are optional for plain curl clients.
        file_mtime = self.headers.get("X-Zim-Mtime", "")

        dest = zim_path(self.cfg, name)
        part = dest + ".part"
        meta = part + ".json"
        lock = self.library.upload_lock(name)
        if not lock.acquire(blocking=False):
            raise AdminError(HTTPStatus.CONFLICT, f"{name} is already being uploaded")
        try:
            if os.path.exists(dest) and not overwrite:
                raise AdminError(HTTPStatus.CONFLICT, f"{name} already exists")
            current = os.path.getsize(part) if os.path.exists(part) else 0
            if reset:
                for path in (part, meta):
                    try:
                        os.unlink(path)
                    except OSError:
                        pass
                current = 0
            if offset != current:
                raise AdminError(
                    HTTPStatus.CONFLICT,
                    f"expected offset {current}, got {offset}; restart the upload",
                )
            if current and file_mtime and os.path.exists(meta):
                try:
                    with open(meta, encoding="utf-8") as fh:
                        saved = json.load(fh)
                except (OSError, ValueError):
                    saved = {}
                saved_mtime = saved.get("mtime")
                saved_size = saved.get("size")
                if saved_mtime not in (None, file_mtime) or saved_size not in (None, total):
                    raise AdminError(
                        HTTPStatus.CONFLICT,
                        "the interrupted upload belongs to a different copy of this file; restart it",
                    )
            needed = total - current
            sv = os.statvfs(self.cfg.zim_dir)
            free = sv.f_bavail * sv.f_frsize
            if needed > free:
                raise AdminError(
                    HTTPStatus.INSUFFICIENT_STORAGE,
                    f"not enough space: {needed} bytes needed, {free} free",
                )

            remaining = length
            try:
                with open(part, "ab" if current else "wb") as fh:
                    while remaining:
                        block = self.rfile.read(min(COPY_BUFFER, remaining))
                        if not block:
                            raise AdminError(HTTPStatus.BAD_REQUEST, "upload ended early")
                        fh.write(block)
                        remaining -= len(block)
            except OSError as exc:
                # Drop the half-received chunk so the same offset can be retried after the
                # cause (usually a full disk) is fixed.
                try:
                    os.truncate(part, current)
                except OSError:
                    pass
                raise AdminError(HTTPStatus.INSUFFICIENT_STORAGE, f"write failed: {exc}")

            written = os.path.getsize(part)
            if offset == 0 and written >= len(ZIM_MAGIC):
                with open(part, "rb") as fh:
                    if fh.read(len(ZIM_MAGIC)) != ZIM_MAGIC:
                        fh.close()
                        os.unlink(part)
                        raise AdminError(HTTPStatus.UNSUPPORTED_MEDIA_TYPE, "not a ZIM archive (bad magic)")
            if written != offset + length:
                raise AdminError(HTTPStatus.INTERNAL_SERVER_ERROR, "upload size mismatch on disk")
            if offset == 0:
                try:
                    with open(meta, "w", encoding="utf-8") as fh:
                        json.dump({"mtime": file_mtime, "size": total}, fh)
                except OSError:
                    pass  # a missing sidecar only disables the resume check
            if written == total:
                try:
                    size = self.library.finish(part, dest)
                except AdminError:
                    try:
                        os.unlink(meta)
                    except OSError:
                        pass
                    raise
                try:
                    os.unlink(meta)
                except OSError:
                    pass
                self.log_message("uploaded %s (%d bytes)", name, size)
                self.send_json({"ok": True, "done": True, "name": name, "size": size})
            else:
                self.send_json({"ok": True, "done": False, "name": name, "received": written, "total": total})
        finally:
            lock.release()


def quote_name(name):
    return quote(name, safe="")


# --------------------------------------------------------------------------- main
def parse_args(argv):
    parser = argparse.ArgumentParser(
        description="Ktemata library admin: manage ZIM archives and kiwix-serve from a browser.",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog=(
            "Credentials come from --auth-file, a KEY=VALUE file with KTEMATA_ADMIN_USER and\n"
            "KTEMATA_ADMIN_PASSWORD. Without them the server binds 127.0.0.1 only."
        ),
    )
    parser.add_argument("--zim-dir", default=os.environ.get("KTEMATA_ZIM_DIR", DEFAULT_ZIM_DIR))
    parser.add_argument("--state-dir", default=os.environ.get("KTEMATA_STATE_DIR", DEFAULT_STATE_DIR))
    parser.add_argument("--port", type=int, default=DEFAULT_PORT, help=f"listen port (default {DEFAULT_PORT})")
    parser.add_argument("--bind", default=None, help="listen address (default: all interfaces with auth, else loopback)")
    parser.add_argument(
        "--library-port",
        type=int,
        default=DEFAULT_LIBRARY_PORT,
        help=f"kiwix-serve port the page links to (default {DEFAULT_LIBRARY_PORT})",
    )
    parser.add_argument("--service", default=DEFAULT_SERVICE, help=f"systemd unit (default {DEFAULT_SERVICE})")
    parser.add_argument(
        "--library-helper",
        default=DEFAULT_LIBRARY_HELPER,
        help=f"kiwix-library helper (default {DEFAULT_LIBRARY_HELPER})",
    )
    parser.add_argument("--assets", default=None, help="directory with index.html/style.css/app.js")
    parser.add_argument("--auth-file", default=None, help=f"credentials file (default {DEFAULT_AUTH_FILE} if present)")
    parser.add_argument("--auth-user", default=None, help=argparse.SUPPRESS)
    parser.add_argument("--auth-password", default=None, help=argparse.SUPPRESS)
    parser.add_argument("--version", action="version", version=f"%(prog)s {VERSION}")
    return parser.parse_args(argv)


def main(argv=None):
    args = parse_args(argv)
    cfg = Config(args)
    if not os.path.isdir(cfg.zim_dir):
        raise SystemExit(f"ktemata-admin: ZIM directory does not exist: {cfg.zim_dir}")
    if cfg.auth_enabled and len(cfg.password) < 8:
        raise SystemExit("ktemata-admin: the admin password must be at least 8 characters")
    if not cfg.auth_enabled:
        sys.stderr.write(
            "ktemata-admin: no credentials configured; listening on loopback only.\n"
            "              Pass --auth-file /etc/ktemata/admin.conf to serve the LAN.\n"
        )

    Handler.cfg = cfg
    Handler.library = Library(cfg)

    try:
        httpd = ThreadingHTTPServer((cfg.bind, cfg.port), Handler)
    except OSError as exc:
        raise SystemExit(f"ktemata-admin: cannot listen on {cfg.bind}:{cfg.port}: {exc}")
    host, port = httpd.server_address[:2]
    shown = f"[{host}]" if ":" in host else host
    sys.stderr.write(
        f"ktemata-admin {VERSION}: http://{shown}:{port}/  library={cfg.zim_dir}  service={cfg.service}"
        f"  auth={'on' if cfg.auth_enabled else 'off'}\n"
    )
    try:
        httpd.serve_forever()
    except KeyboardInterrupt:
        pass
    finally:
        httpd.server_close()


if __name__ == "__main__":
    main()
