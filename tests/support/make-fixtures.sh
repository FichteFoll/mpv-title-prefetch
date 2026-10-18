#!/bin/sh
# Generates the media fixtures for the tests into the given directory.
set -eu

dir=$1
mkdir -p "$dir"

video() {
    ffmpeg -v error -y -f lavfi -i testsrc=d=0.2:s=64x48 "$@"
}

for n in $(seq 1 15); do
    video -metadata "title=Title $n" "$dir/titled-$n.mkv"
done
video "$dir/untitled.mkv"
ffmpeg -v error -y -f lavfi -i sine=d=0.2 -c:a libopus \
    -metadata:s:a:0 "title=Opus Title" "$dir/stream-title.opus"
ffmpeg -v error -y -f lavfi -i sine=d=0.2 -metadata "TITLE=Upper Title" "$dir/upper.flac"
printf '%s\n' '#EXTM3U' '#EXTINF:-1,Kept' titled-1.mkv titled-2.mkv titled-3.mkv > "$dir/kept.m3u"
