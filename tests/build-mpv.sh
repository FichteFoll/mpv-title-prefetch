#!/bin/sh
# Builds mpv with writable `playlist/N/title` into .cache/mpv.
set -eu

# Head of mpv PR #18599 ("player/command: make property playlist/N/title writable").
# Move this to a release tag once the PR is part of a release.
MPV_SHA=c5d47b55df32f62382de0f577b97aadc5d3999ae
MPV_REPO=https://github.com/mpv-player/mpv

root=$(cd "$(dirname "$0")/.." && pwd)
dir="$root/.cache/mpv"
short_sha=$(printf '%.8s' "$MPV_SHA")

if [ -x "$dir/build/mpv" ] && "$dir/build/mpv" --version | grep -q "g$short_sha"; then
    echo "mpv at $short_sha is already built: $dir/build/mpv"
    exit 0
fi

mkdir -p "$dir"
cd "$dir"
[ -d .git ] || git init --quiet
git fetch --depth 1 "$MPV_REPO" "$MPV_SHA"
git checkout --quiet --force FETCH_HEAD

if [ ! -d build ]; then
    meson setup build -Dlua=luajit -Dlibmpv=false -Dmanpage-build=disabled -Dhtml-build=disabled
fi
ninja -C build
"$dir/build/mpv" --version | head -n 1
