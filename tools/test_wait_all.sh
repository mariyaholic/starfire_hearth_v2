#!/usr/bin/env bash
set -eu
source "$(dirname "$0")/wait_all.sh"
marker=$(mktemp)
trap 'rm -f "$marker"' EXIT
(false) & first=$!
(sleep 0.1; printf done > "$marker") & second=$!
if wait_all "$first" "$second"; then
  echo 'wait_all failed to report a failed child' >&2
  exit 1
fi
[ "$(cat "$marker")" = done ] || { echo 'wait_all failed to reap every child' >&2; exit 1; }
(true) & first=$!
(true) & second=$!
wait_all "$first" "$second"
echo 'wait_all regression passed'
