#!/usr/bin/env python3
"""Inspect and validate the Kiwix ZIM library used by the Ktemata / Project Nomad build.

The ZIM files live on the external disk (default /run/media/joost/data/zim) and are
listed in zim/zim.md. This tool reads each archive with libzim (no compiler needed; the
libzim wheel is prebuilt) and prints what the Pi actually gets:

  python3 work/scripts/zim.py                      # table of the library + totals
  python3 work/scripts/zim.py --dir /path/to/zim   # a different library
  python3 work/scripts/zim.py --check              # also verify checksums (slow)
  python3 work/scripts/zim.py --missing            # list zim/zim.md entries not on disk
  python3 work/scripts/zim.py --extra              # list on-disk files missing from zim.md
  python3 work/scripts/zim.py --update-list        # rewrite zim/zim.md from the disk

Exit status is 1 when --check finds a corrupt archive, or when --missing finds listed
files that are absent. Read-only: this never writes to a ZIM file.
"""
import argparse
import os
import sys

try:
    from libzim.reader import Archive
except ImportError:
    sys.exit("libzim is missing: .venv/bin/pip install libzim")

DEFAULT_DIR = "/run/media/joost/data/zim"
LIST = os.path.join(os.path.dirname(os.path.dirname(os.path.dirname(
    os.path.abspath(__file__)))), "zim", "zim.md")


def human(n):
    for unit in ("B", "KB", "MB", "GB", "TB"):
        if n < 1024 or unit == "TB":
            return f"{n:.0f} {unit}" if unit == "B" else f"{n:.1f} {unit}"
        n /= 1024


def short_langs(value, limit=3):
    """'eng,fra,deu,...' -> 'eng,fra,deu,+17' so the column stays readable."""
    parts = [p.strip() for p in value.split(",") if p.strip()] if value != "-" else []
    if len(parts) <= limit:
        return ",".join(parts) or "-"
    return ",".join(parts[:limit]) + f",+{len(parts) - limit}"


def meta(a, key, default="-"):
    try:
        v = a.get_metadata(key)
    except (KeyError, RuntimeError):
        return default
    if isinstance(v, bytes):
        v = v.decode("utf-8", "replace")
    return v.strip() or default


def scan(folder):
    """Return [(filename, path, size)] for every .zim in folder, sorted by name."""
    out = []
    for name in sorted(os.listdir(folder)):
        if not name.endswith(".zim"):
            continue
        path = os.path.join(folder, name)
        if os.path.isfile(path):
            out.append((name, path, os.path.getsize(path)))
    return out


def read_list(path=LIST):
    """Names listed in zim/zim.md (bullets ending in .zim)."""
    if not os.path.exists(path):
        return []
    names = []
    with open(path) as f:
        for line in f:
            line = line.strip()
            if line.startswith("- ") and line.endswith(".zim"):
                names.append(line[2:].strip())
    return names


def inspect(name, path, size, check=False):
    """Open one archive; return a row dict. check=True verifies the checksum."""
    row = {"file": name, "size": size, "ok": True, "note": ""}
    try:
        a = Archive(path)
        row.update(
            title=meta(a, "Title"),
            date=meta(a, "Date"),
            lang=short_langs(meta(a, "Language")),
            # all_entry_count, not article_count: the zimgit/cdc packages are single-page
            # apps with hundreds of media entries, which report article_count == 1
            entries=a.all_entry_count,
            media=a.media_count,
            tags=meta(a, "Tags"),
        )
        if check:
            if not a.has_checksum:
                row["note"] = "no checksum"
            elif a.check() is True:           # libzim returns True when the checksum matches
                row["note"] = "checksum ok"
            else:
                row["ok"] = False
                row["note"] = "CORRUPT"
    except (RuntimeError, OSError, KeyError) as exc:   # libzim raises RuntimeError/IOError
        row.update(title="-", date="-", lang="-", entries=0, media=0, tags="-",
                   ok=False, note=f"{type(exc).__name__}: {exc}")
    return row


def print_table(rows):
    title_w = min(38, max(len(str(r["title"])) for r in rows))
    w = [max(len(str(r["file"])) for r in rows), title_w,
         max(len(str(r["date"])) for r in rows),
         max(len(str(r["lang"])) for r in rows),
         max(len(str(r["entries"])) for r in rows),
         max(len(human(r["size"])) for r in rows)]
    head = (f"{'file':{w[0]}}  {'title':{w[1]}}  {'date':{w[2]}}  {'lang':{w[3]}}  "
            f"{'entries':>{w[4]}}  {'size':>{w[5]}}")
    print(head)
    print("-" * len(head))
    for r in rows:
        title = r["title"]
        title = title if len(title) <= w[1] else title[:w[1] - 1] + "\u2026"
        print(f"{r['file']:{w[0]}}  {title:{w[1]}}  {r['date']:{w[2]}}  "
              f"{r['lang']:{w[3]}}  {r['entries']:>{w[4]}}  {human(r['size']):>{w[5]}}"
              + (f"   {r['note']}" if r["note"] else ""))


def write_list(rows, path=LIST):
    """Rewrite the bullet list in zim/zim.md, keeping the prose around it."""
    lines = []
    if os.path.exists(path):
        with open(path) as f:
            existing = f.read().splitlines()
        for line in existing:
            s = line.strip()
            # drop the old bullet list and any stray ls/shell output pasted into the file
            if s.startswith("- ") and s.endswith(".zim"):
                continue
            if s.startswith(("Permissions Size", ".rw-", "-rw-")):
                continue
            lines.append(line)
    else:
        lines = ["# zim files (Kiwix)", "", "list of *my* zim files (Kiwix) saved on external disk:", ""]
    # insert directly after the intro line, one blank line before the list
    first = next((i for i, l in enumerate(lines) if l.startswith("list of")), len(lines) - 1)
    while first + 1 < len(lines) and lines[first + 1].strip() == "":
        del lines[first + 1]
    block = [""] + ["- " + r["file"] for r in rows]
    lines[first + 1:first + 1] = block
    with open(path, "w") as f:
        f.write("\n".join(lines).rstrip() + "\n")


def main():
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--dir", default=DEFAULT_DIR, help=f"ZIM folder (default {DEFAULT_DIR})")
    ap.add_argument("--check", action="store_true", help="verify checksums (slow)")
    ap.add_argument("--missing", action="store_true", help="list zim.md entries not on disk")
    ap.add_argument("--extra", action="store_true", help="list on-disk files missing from zim.md")
    ap.add_argument("--update-list", action="store_true", help="rewrite zim/zim.md from the disk")
    args = ap.parse_args()

    if not os.path.isdir(args.dir):
        sys.exit(f"ZIM folder not found: {args.dir} (is the external disk mounted?)")

    files = scan(args.dir)
    if not files:
        sys.exit(f"no .zim files in {args.dir}")

    rows = [inspect(n, p, s, check=args.check) for n, p, s in files]
    print_table(rows)

    total = sum(r["size"] for r in rows)
    entries = sum(r["entries"] for r in rows)
    print(f"\n{len(rows)} archives, {human(total)} on disk, {entries:,} entries")

    bad = [r for r in rows if not r["ok"]]
    if bad:
        print("\nFAILED:")
        for r in bad:
            print(f"  {r['file']}: {r['note']}")

    listed = read_list()
    on_disk = {r["file"] for r in rows}
    missing = [n for n in listed if n not in on_disk]
    extra = [n for n in on_disk if n not in listed]
    if args.missing or missing:
        print(f"\nlisted in zim/zim.md but not on disk ({len(missing)}):")
        for n in missing:
            print("  " + n)
    if args.extra or extra:
        print(f"\non disk but not in zim/zim.md ({len(extra)}):")
        for n in sorted(extra):
            print("  " + n)
    if args.update_list:
        write_list(rows)
        print(f"\nrewrote {LIST}")

    return 1 if (bad or (args.missing and missing)) else 0


if __name__ == "__main__":
    sys.exit(main())
