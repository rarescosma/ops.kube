#!/usr/bin/env bash

dumpstack() {
  local src
  local kwargs="$*"

  src="$(basename "${BASH_SOURCE[1]}")"
  [[ "$src" =~ ^"$HOME"(/|$) ]] && src="~${src#$HOME}"
  printf "%s | %s | %s(%s) @ %s:%s\\n" "$(date +%F@%T)" "${VM_HOST}" \
    "${FUNCNAME[1]}" "$kwargs" "$src" "${BASH_LINENO[0]}" >&2
}

load_env() {
  for _file in $(echo "$@" | tr ' ' '\n'); do
    if test -f "${_file}"; then
      # shellcheck source=/dev/null
      source "${_file}"
      export $(\
        cat "${_file}" \
        | sed '/^[[:space:]]*$/d' \
        | sed '/^#.*$/d' \
        | cut -d= -f1\
      ) >/dev/null
    fi
  done
}

utils::download() {
  local url=$1
  local dest=$2

  if [ -x "$(command -v axel)" ]; then
    axel -n 4 -o "$dest" "$url"
  else
    curl -sL "$url" -o "$dest"
  fi
}

utils::pluck_binaries() {
  local tmp
  tmp=$(mktemp -d)
  local url="${1}"
  local dest_dir="${2}"
  mkdir -p "${dest_dir}"

  utils::download "$url" "${tmp}/archive.tgz"
  tar -C "${tmp}" -xf "${tmp}/archive.tgz"
  find "${tmp}" -type f -executable -print0 | \
    xargs -0 -I{} mv {} "${dest_dir}/"
  rm -rf "${tmp:?}"
}

utils::template() {
  envsubst <"${1}"
}

utils::get_random_string() {
  uuidgen || cat /dev/urandom | tr -dc A-Za-z0-9 | head -c"${1:-8}"
}

utils::get_ip() {
  local interface=${1:-"$VM_IFACE"}
  ip addr show dev "$interface" \
  | grep -v inet6 | grep inet \
  | cut -d"/" -f1 \
  | sed 's/[^0-9.]*//g'
}

utils::wait_ip() {
  local interface=${1:-"$VM_IFACE"}
  dumpstack "${interface}"
  local ip
  while true; do
    ip=$(utils::get_ip "$interface")
    if [[ "${ip}" != "" ]]; then
      echo "$ip" && break
    fi
    sleep 1
  done
}

utils::export_vm() {
  vm::assert_vm

  VM_HOST=$(hostname -s)
  VM_IP=$(utils::wait_ip)
  OUT_DIR="/kube"

  export VM_HOST VM_IP OUT_DIR
}

utils::to_upper() {
  echo "$@" | tr '[:lower:]' '[:upper:]'
}

utils::replace_line_by_prefix() {
  local fname=$1
  local prefix=$2
  local content=$3

  local tmp
  tmp=$(mktemp -d)

  set +e
  grep -v "$prefix" < "$fname" > "$tmp/grepped"
  echo "${prefix}${content}" | tee -a "$tmp/grepped"
  mv "$tmp/grepped" "$fname"
  rm -rf "$tmp"
  set -e
}

utils::service_ip() {
  local service_subnet="$1"
  echo "$service_subnet" | sed -r 's/(.*)\.[[:digit:]]+\/[[:digit:]]+/\1/'
}

utils::function_exists() {
  [ -n "$(type -t "$1")" ] && [ "$(type -t "$1")" = function ]
}
