#!/usr/bin/env bash
# Wait for every supplied child, returning failure if any child failed.
wait_all() {
  local failed=0 pid
  for pid in "$@"; do
    if ! wait "$pid"; then failed=1; fi
  done
  return "$failed"
}
