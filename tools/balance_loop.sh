#!/bin/bash
# The local balance loop (the CI balance job's runs, in parallel): the four policies on Normal and
# the balanced bot on Story, 105 turns each, then every gate in advisory mode.
#   tools/balance_loop.sh <out dir> [seeds, default 1-20]
set -u
OUT=${1:?usage: tools/balance_loop.sh <out dir> [seeds]}
SEEDS=${2:-1-20}
cd "$(dirname "$0")/.."
rm -rf "$OUT"
mkdir -p "$OUT/story"
pids=()
for p in balanced economy turtle random-legal; do
  godot --headless --path . -s tools/bot_run.gd -- --scenario s1 --policy "$p" --seeds "$SEEDS" --turns 105 --out "$OUT" > "$OUT/log_$p.txt" 2>&1 &
  pids+=($!)
done
godot --headless --path . -s tools/bot_run.gd -- --scenario s1 --policy balanced --seeds "$SEEDS" --turns 105 --difficulty story --out "$OUT/story" > "$OUT/log_story.txt" 2>&1 &
pids+=($!)
for pid in "${pids[@]}"; do
  wait "$pid"
done
cp "$OUT"/story/*.json "$OUT"/
godot --headless --path . -s tools/telemetry_report.gd -- --in "$OUT" --balance advisory
