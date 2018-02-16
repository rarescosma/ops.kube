#!/usr/bin/env bash

dumpstack() {
  local src
  local kwargs="$*"

  src="$(basename "${BASH_SOURCE[1]}")"
  [[ "$src" =~ ^"$HOME"(/|$) ]] && src="~${src#$HOME}"
  printf "%s | %s | %s(%s) @ %s:%s\\n" "$(date +%F@%T)" "${VM_HOST}" \
    "${FUNCNAME[1]}" "$kwargs" "$src" "${BASH_LINENO[0]}" >&2
}
