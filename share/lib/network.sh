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
  for worker_ip in $(vm::discover worker ips); do
    docker_subnet=$(utils::docker_subnet "$worker_ip")
    sudo route del -net "$docker_subnet" &>/dev/null || true
    sudo route add -net "$docker_subnet" gw "$worker_ip"

    # Proxy services thru all workers
    sudo route del -net "$KUBE_SERVICE_CLUSTER_IP_RANGE" &>/dev/null || true
    sudo route add -net "$KUBE_SERVICE_CLUSTER_IP_RANGE" gw "$worker_ip"
  done
}

network::stop() {
  dumpstack "$*"
  for subnet in $(seq 1 255); do
    sudo route del -net "10.${subnet}.0.0/16" &>/dev/null || true &
  done
  wait
  sudo route del -net "$KUBE_SERVICE_CLUSTER_IP_RANGE" &>/dev/null || true
}
