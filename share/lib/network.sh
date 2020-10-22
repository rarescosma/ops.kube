#!/usr/bin/env bash

network::cycle() {
  dumpstack "$*"
  network::stop
  network::start
}

network::pod_cidr() {
  local worker_ip=$1
  echo "10.$(echo "$worker_ip" | cut -d. -f4).0.0/16"
}

network::gateway() {
  dumpstack "$*"
  ip route | grep default | cut -d" " -f3
}

network::start() {
  dumpstack "$*"
  local pod_cidr worker_ip our_worker_ip

  # Find all worker IPs
  for worker_ip in $(vm::discover '' worker ips); do
    pod_cidr=$(network::pod_cidr "$worker_ip")
    sudo ip route add "$pod_cidr" via "$worker_ip" || true
  done

  for our_worker_ip in $(vm::discover "$CLUSTER" worker ips); do
    # Proxy services through the first worker
    sudo ip route add $(_network::cluster_range "$SERVICE_CIDR") via "$our_worker_ip" || true
    break
  done
}

network::stop() {
  dumpstack "$*"
  local pod_cidr our_worker_ip

  for our_worker_ip in $(vm::discover "$CLUSTER" worker ips); do
    pod_cidr=$(network::pod_cidr "$our_worker_ip")
    sudo ip route del "$pod_cidr" &>/dev/null || true
  done
  sudo ip route del $(_network::cluster_range "$SERVICE_CIDR") &>/dev/null || true
}

_network::cluster_range() {
  local service_range
  service_range="${1}"
  echo "$service_range" | sed -r 's|/[0-9]+|/16|'
}
