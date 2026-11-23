#!/bin/sh
# Rebuild Kiwix's library XML only when the ZIM input metadata changes.
set -eu

if [ "$#" -ne 2 ]; then
    printf 'Usage: %s ZIM_DIRECTORY LIBRARY_XML\n' "$0" >&2
    exit 2
fi

dir=$1
xml=$2
cache="$xml.inputs.sha256"
manifest="$cache.manifest"
tmp="$xml.tmp"

set --
for z in "$dir"/*.zim; do
    [ -e "$z" ] && set -- "$@" "$z"
done

# An empty library must not keep serving an XML left over from removed archives.
if [ "$#" -eq 0 ]; then
    rm -f "$xml" "$cache" "$tmp"
    printf 'No ZIM files in %s; library XML cleared\n' "$dir"
    exit 0
fi

trap 'rm -f "$manifest" "$tmp" "$cache.tmp"' EXIT HUP INT TERM

# Full content hashes would read every archive on every start. Paths, sizes and mtimes catch
# additions, removals and normal replacements without reading the ZIM payloads.
: >"$manifest"
for z in "$@"; do
    metadata=$(stat -c '%s|%y' "$z" 2>/dev/null) || metadata=$(stat -f '%z|%m' "$z")
    size=${metadata%%|*}
    mtime=${metadata#*|}
    printf '%s\0%s\0%s\0' "${z##*/}" "$size" "$mtime" >>"$manifest"
done
LC_ALL=C sort -z -o "$manifest" "$manifest"
fingerprint=$(sha256sum "$manifest")
fingerprint=${fingerprint%% *}

if [ -s "$xml" ] && [ -r "$cache" ] && [ "$(cat "$cache")" = "$fingerprint" ]; then
    printf 'Library unchanged (%d ZIM archive(s)); skipping XML rebuild\n' "$#"
    exit 0
fi

printf '<library version="20110515">\n</library>\n' >"$tmp"
for z in "$@"; do
    kiwix-manage "$tmp" add "$z"
done
mv "$tmp" "$xml"
printf '%s\n' "$fingerprint" >"$cache.tmp"
mv "$cache.tmp" "$cache"
chmod 0644 "$xml" "$cache"
printf 'library.xml rebuilt: %d ZIM archive(s)\n' "$#"
