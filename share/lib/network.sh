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

network::start() {
  dumpstack "$*"
  local docker_subnet

  # Find all worker IPs
  for worker_ip in $(vm::discover '' worker ips); do
    docker_subnet=$(utils::docker_subnet "$worker_ip")
    sudo ip route del "$docker_subnet" &>/dev/null || true
    sudo ip route add "$docker_subnet" via "$worker_ip"
  done

  for our_worker_ip in $(vm::discover "$CLUSTER" worker ips); do
    # Proxy services through the first worker
    sudo ip route del "$KUBE_SERVICE_CLUSTER_IP_RANGE" &>/dev/null || true
    sudo ip route add "$KUBE_SERVICE_CLUSTER_IP_RANGE" via "$our_worker_ip"
    break
  done
}

network::stop() {
  dumpstack "$*"
  for subnet in $(seq 1 255); do
    sudo ip route del "10.${subnet}.0.0/16" &>/dev/null || true &
  done
  wait
  sudo ip route del "$KUBE_SERVICE_CLUSTER_IP_RANGE" &>/dev/null || true
}
