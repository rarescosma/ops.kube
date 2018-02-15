#!/usr/bin/env bash

dumpstack() {
  local src
  local kwargs="$*"

  src="$(readlink -f "${BASH_SOURCE[1]}")"
  [[ "$src" =~ ^"$HOME"(/|$) ]] && src="~${src#$HOME}"
  printf "%s:%s > %s(%s)\\n" "$src" "${BASH_LINENO[0]}" "${FUNCNAME[1]}" "$kwargs" >&2
}
