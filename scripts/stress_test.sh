#!/bin/bash
# Relaunches the debug AudioBunny binary repeatedly to catch nondeterministic
# launch-time crashes (e.g. the main-actor-contention AttributeGraph crash
# fixed in July 2026) that a single run or unit test won't reliably surface.
#
# Usage: scripts/stress_test.sh [trial_count]

set -euo pipefail
set +m  # suppress job-control "Killed" notifications when we pkill background trials

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MACOS_DIR="$(dirname "$SCRIPT_DIR")"
BINARY="$MACOS_DIR/.build/debug/AudioBunny"
TRIALS="${1:-8}"
CRASH_DIR="$HOME/Library/Logs/DiagnosticReports"

if [ ! -x "$BINARY" ]; then
    echo "▸ Building debug binary…"
    (cd "$MACOS_DIR" && swift build -c debug)
fi

before=0
if [ -d "$CRASH_DIR" ]; then
    before=$(ls "$CRASH_DIR" 2>/dev/null | grep -ci audiobunny || true)
fi

echo "▸ Relaunching AudioBunny $TRIALS times to check for launch-time crashes…"
failures=0
for trial in $(seq 1 "$TRIALS"); do
    pkill -9 -f "$BINARY" 2>/dev/null || true
    sleep 0.3
    "$BINARY" > /dev/null 2>&1 &
    pid=$!
    disown "$pid" 2>/dev/null || true
    sleep 1.5
    if kill -0 "$pid" 2>/dev/null; then
        echo "  trial $trial: alive"
    else
        echo "  trial $trial: DEAD"
        failures=$((failures + 1))
    fi
done
pkill -9 -f "$BINARY" 2>/dev/null || true

after=0
if [ -d "$CRASH_DIR" ]; then
    after=$(ls "$CRASH_DIR" 2>/dev/null | grep -ci audiobunny || true)
fi
new_crashes=$((after - before))

if [ "$failures" -gt 0 ] || [ "$new_crashes" -gt 0 ]; then
    echo "✗ Stress test FAILED: $failures/$TRIALS trials died, $new_crashes new crash report(s) in $CRASH_DIR"
    exit 1
fi

echo "✓ Stress test passed: $TRIALS/$TRIALS trials survived, no new crash reports"
