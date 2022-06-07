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

  # Delete obsolete routes
  network::stop

  # Find all worker IPs
  for worker_ip in $(vm::discover worker ips; vm::discover master ips); do
    pod_cidr=$(network::pod_cidr "$worker_ip")
    sudo ip route add "$pod_cidr" via "$worker_ip" || true
  done
  sudo ip route add "${SERVICE_CIDR}" $(_network::service_hops) || true
}

network::stop() {
  dumpstack "$*"

  ip route | grep -E "lxdbr0\s?$" \
  | cut -d" " -f1 \
  | xargs -I{} sudo ip route del {};

  sudo ip route del "$SERVICE_CIDR" &>/dev/null || true
}

_network::service_hops() {
  for our_worker_ip in $(vm::discover worker ips; vm::discover master ips); do
    echo -n "nexthop via ${our_worker_ip} dev ${LXD_BRIDGE} weight 1 "
  done
}
