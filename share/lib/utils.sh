#!/usr/bin/env bash

# Shhhhhh...
pushd() {
  command pushd "$@" > /dev/null
}
popd() {
  command popd "$@" > /dev/null
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

utils::pull_tgz() {
  local tmp
  tmp=$(mktemp -d)
  local url=$1
  local target=$2
  local glob_prefix=$3

  utils::download "$url" "${tmp}/archive.tgz"
  tar --strip-components=1 -C "$tmp" -xf "$tmp/archive.tgz"
  mv "$tmp/${glob_prefix}"* "$target/"
  rm -rf "$tmp"
}

utils::template() {
  eval "echo \"$(cat "$1")\""
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
  dumpstack "${VM_IFACE}"
  local ip
  while true; do
    ip=$(utils::get_ip "$VM_IFACE")
    if [[ "${ip}" != "" ]]; then
      echo "$ip" && break
    fi
    sleep 1
  done
}

utils::export_vm() {
  vm::assert_vm

  VM_HOSTNAME=$(hostname)
  export VM_HOSTNAME

  VM_IP=$(utils::wait_ip)
  export VM_IP
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

utils::docker_subnet() {
  local worker_ip=$1
  echo "10.$(echo "$worker_ip" | cut -d. -f4).0.0/16"
}

utils::service_ip() {
  local service_subnet="$1"
  echo "$service_subnet" | sed -r 's/(.*)\.[[:digit:]]+\/[[:digit:]]+/\1.1/'
}

utils::function_exists() {
  [ -n "$(type -t "$1")" ] && [ "$(type -t "$1")" = function ]
}
