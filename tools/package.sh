#!/bin/sh
# Builds the release zip, laid out like the mpv config directory.
# Usage: tools/package.sh [output.zip], default `.cache/dist/title-prefetch.zip`.
set -eu

ROOT=$(cd "$(dirname "$0")/.." && pwd)
out=${1:-$ROOT/.cache/dist/title-prefetch.zip}

mkdir -p "$(dirname "$out")"
out=$(cd "$(dirname "$out")" && pwd)/$(basename "$out")
rm -f "$out"

STAGE=$(mktemp -d)
trap 'rm -rf "$STAGE"' EXIT

mkdir -p "$STAGE/scripts" "$STAGE/script-opts"
cp -R "$ROOT/title-prefetch" "$STAGE/scripts/title-prefetch"
cp "$ROOT/LICENSE" "$STAGE/scripts/title-prefetch/LICENSE"
cp "$ROOT/title-prefetch.conf" "$STAGE/script-opts/title-prefetch.conf.example"

# -D omits directory entries, which keeps the listing to files.
(cd "$STAGE" && zip -qrD "$out" scripts script-opts)

echo "$out"
