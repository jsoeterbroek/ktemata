# ZIM

All ZIM files live on the external WD drive, mounted at `/run/media/joost/data/zim`.

- [`zim.md`](zim.md) — the curated list of my files, with sizes and what each covers.
- Check the library and keep the list in sync:

```bash
.venv/bin/python work/scripts/zim.py              # table: titles, dates, languages, entries, sizes
.venv/bin/python work/scripts/zim.py --check      # verify checksums (slow)
.venv/bin/python work/scripts/zim.py --missing    # listed but absent
.venv/bin/python work/scripts/zim.py --update-list  # rewrite zim.md from disk
```

The `*.zim` files are git-ignored (they are hundreds of GB); only this list is tracked.
