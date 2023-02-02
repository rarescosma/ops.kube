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

utils::wait_for_ip() {
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

utils::wait_for_net() {
  dumpstack
  while ! ping -c1 www.google.com &>/dev/null; do sleep 1; done
}

utils::export_vm() {
  vm::assert_vm

  VM_HOST=$(hostname -s)
  VM_IP=$(utils::wait_for_ip)
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

utils::setup_haproxy_lb() {
  dumpstack
  local num_cpus=$1
  shift

  local cfg_file="/etc/haproxy/haproxy.cfg"
  sudo mkdir -p $(dirname $cfg_file)

  (
    cat << __EOF__
global
  log /dev/log	local0
  log /dev/log	local1 notice
  chroot /var/lib/haproxy
  stats socket /run/haproxy/admin.sock mode 660 level admin expose-fd listeners
  stats timeout 30s
  stats bind-process ${num_cpus}
  user haproxy
  group haproxy
  daemon
  nbproc ${num_cpus}
__EOF__
    for cpu in $(seq 1 $num_cpus); do
      echo "  cpu-map $cpu $((cpu - 1))"
    done
    cat  << __EOF__

defaults
  timeout connect 5s
  timeout client 30s
  timeout server 10s
  maxconn 50000

backend logger
  stick-table type ip size 100k expire 3m store conn_rate(3s),gpc0,conn_cur

frontend plain_proxy
  bind *:80
  mode tcp
  tcp-request content accept if { src 10.0.0.0/8 }
  tcp-request content reject if { src_conn_rate(logger) ge 20 }
  tcp-request content reject if { src_conn_cur(logger) ge 100 }
  tcp-request content track-sc1 src table logger
  use_backend plain_nginx

frontend ssl_proxy
  bind *:443
  mode tcp
  tcp-request content accept if { src 10.0.0.0/8 }
  tcp-request content reject if { src_conn_rate(logger) ge 20 }
  tcp-request content reject if { src_conn_cur(logger) ge 100 }
  tcp-request content track-sc1 src table logger
  use_backend ssl_nginx

backend plain_nginx
  mode tcp
  log global
__EOF__
    local j=1
    for worker_ip in $(vm::discover worker ips); do
      echo "  server nginx${j} ${worker_ip}:10080 send-proxy check"
      j=$((j+1))
    done
    cat  << __EOF__

backend ssl_nginx
  mode tcp
  log global
__EOF__
    local j=1
    for worker_ip in $(vm::discover worker ips); do
      echo "  server nginx${j} ${worker_ip}:10443 send-proxy check"
      j=$((j+1))
    done
  ) | sudo tee $cfg_file

  haproxy -f $cfg_file -c && sudo systemctl reload haproxy
}

utils::wait_for_master() {
  dumpstack

  while ! kubectl get node master0-${CLUSTER} 2>/dev/null; do
    sleep 1
  done
  kubectl wait --for=condition=Ready node/master0-${CLUSTER}
}

utils::ensure_kubectl() {
  if ! command -v kubectl >/dev/null; then
    mkdir -p "${HOME}"/bin
    utils::download "https://storage.googleapis.com/kubernetes-release/release/v${V_KUBE}/bin/linux/amd64/kubectl" "${HOME}/bin/kubectl"
    chmod +x "${HOME}/bin/kubectl"
  fi
}
