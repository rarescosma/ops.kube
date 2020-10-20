#!/usr/bin/env bash

network::cycle() {
  dumpstack "$*"
  network::stop
  network::start
}

network::flush_iptables() {
  dumpstack "$*"
  echo '> Flushing all iptables rules...'
  local ipt="sudo /sbin/iptables"

  $ipt -P INPUT ACCEPT
  $ipt -P FORWARD ACCEPT
  $ipt -P OUTPUT ACCEPT
  $ipt -F
  $ipt -X
  $ipt -t nat -F
  $ipt -t nat -X
  $ipt -t mangle -F
  $ipt -t mangle -X
  $ipt -t raw -F
  $ipt -t raw -X
}

network::gateway() {
  dumpstack "$*"
  ip route | grep default | cut -d" " -f3
}

network::start() {
  dumpstack "$*"
  local docker_subnet worker_ip our_worker_ip

  # Find all worker IPs
  for worker_ip in $(vm::discover '' worker ips); do
    docker_subnet=$(utils::docker_subnet "$worker_ip")
    sudo ip route add "$docker_subnet" via "$worker_ip" || true
  done

  for our_worker_ip in $(vm::discover "$CLUSTER" worker ips); do
    # Proxy services through the first worker
    sudo ip route add $(_network::cluster_range "$KUBE_SERVICE_CLUSTER_IP_RANGE") via "$our_worker_ip" || true
    break
  done
}

network::stop() {
  dumpstack "$*"
  local our_worker_ip

  for our_worker_ip in $(vm::discover "$CLUSTER" worker ips); do
    docker_subnet=$(utils::docker_subnet "$our_worker_ip")
    sudo ip route del "$docker_subnet" &>/dev/null || true &
  done
  wait
  sudo ip route del $(_network::cluster_range "$KUBE_SERVICE_CLUSTER_IP_RANGE") &>/dev/null || true
}

_network::cluster_range() {
  local service_range
  service_range="${1}"
  echo "$service_range" | sed -r 's|/[0-9]+|/16|'
}
