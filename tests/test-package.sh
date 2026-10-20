#!/bin/sh
# Checks that the release zip built by tools/package.sh has the expected layout.
# Usage: tests/test-package.sh
set -eu

ROOT=$(cd "$(dirname "$0")/.." && pwd)
WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT

"$ROOT/tools/package.sh" "$WORK/title-prefetch.zip" >/dev/null

unzip -Z1 "$WORK/title-prefetch.zip" | sort > "$WORK/actual"
{
    echo script-opts/title-prefetch.conf.example
    echo scripts/title-prefetch/LICENSE
    (cd "$ROOT" && find title-prefetch -type f) | sed 's|^|scripts/|'
} | sort > "$WORK/expected"

if ! diff -u "$WORK/expected" "$WORK/actual"; then
    echo "FAIL package: unexpected zip listing" >&2
    exit 1
fi

unzip -q "$WORK/title-prefetch.zip" -d "$WORK/extracted"
if ! cmp "$ROOT/title-prefetch.conf" "$WORK/extracted/script-opts/title-prefetch.conf.example"; then
    echo "FAIL package: example config differs from title-prefetch.conf" >&2
    exit 1
fi

echo "PASS package"
