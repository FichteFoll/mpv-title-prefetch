#!/bin/sh
# Runs the tests/test_*.lua driver scripts headless in mpv.
# Usage: tests/run.sh [name ...], where a name is a test file's basename without `.lua`.
set -eu

ROOT=$(cd "$(dirname "$0")/.." && pwd)
TESTS="$ROOT/tests"

if [ -z "${MPV:-}" ]; then
    if [ -x "$ROOT/.cache/mpv/build/mpv" ]; then
        MPV="$ROOT/.cache/mpv/build/mpv"
    else
        MPV=mpv
    fi
fi
case $MPV in
    */*) MPV=$(cd "$(dirname "$MPV")" && pwd)/$(basename "$MPV") ;;
    *) MPV=$(command -v "$MPV") || { echo "mpv binary not found: $MPV" >&2; exit 2; } ;;
esac

if [ $# -eq 0 ]; then
    for test in "$TESTS"/test_*.lua; do
        [ -e "$test" ] && set -- "$@" "$(basename "$test" .lua)"
    done
fi
for name in "$@"; do
    if [ ! -f "$TESTS/$name.lua" ]; then
        echo "no such test: $name" >&2
        exit 2
    fi
done

WORK=$(mktemp -d)
child=
trap 'rm -rf "$WORK"' EXIT
# A trap runs only after a foreground command finishes, and `timeout` keeps mpv out
# of the terminal's process group, so bounded commands run in the background
# and a signal stops the whole run right away.
on_signal() {
    if [ -n "$child" ]; then
        kill "$child" 2>/dev/null || true
        wait "$child" || true
    fi
    exit "$1"
}
trap 'on_signal 130' INT
trap 'on_signal 143' TERM

# Usage: bounded <seconds> <command...>
bounded() {
    timeout "$@" &
    child=$!
    wait "$child"
}
FIXTURES="$WORK/fixtures"
"$TESTS/support/make-fixtures.sh" "$FIXTURES"

if ! bounded 20 "$MPV" --no-config --idle=yes --vo=null --ao=null --pause \
    --script="$TESTS/support/check-mpv.lua" \
    "$FIXTURES/titled-1.mkv" "$FIXTURES/titled-2.mkv" > "$WORK/check-mpv.log" 2>&1
then
    cat "$WORK/check-mpv.log" >&2
    echo "$MPV does not support writing playlist/N/title (mpv PR #18599)." >&2
    echo "Build a suitable mpv with \`mise run build-mpv\`, or point \$MPV at one." >&2
    exit 2
fi

export TP_ROOT="$ROOT" TP_TESTS="$TESTS" TP_FIXTURES="$FIXTURES" TP_MPV="$MPV"

passed=0
failed=0
for name in "$@"; do
    TP_TMP="$WORK/tmp/$name"
    mkdir -p "$TP_TMP"
    export TP_TMP
    log="$WORK/$name.log"
    status=0
    bounded 60 "$MPV" --no-config --idle=yes --pause --vo=null --ao=null \
        --msg-level="all=warn,title_prefetch=debug,$name=info" \
        --script="$ROOT/title-prefetch" --script="$TESTS/$name.lua" \
        > "$log" 2>&1 || status=$?
    if [ "$status" -eq 0 ] && ! grep '^\[title_prefetch\]' "$log" | grep -qE 'Lua error|stack traceback'; then
        echo "PASS $name"
        passed=$((passed + 1))
    else
        echo "FAIL $name (exit status $status)"
        tail -n 40 "$log"
        failed=$((failed + 1))
    fi
done

echo "$passed passed, $failed failed"
[ "$failed" -eq 0 ]
