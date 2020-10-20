#!/usr/bin/env bash

orchestrate::master() {
  dumpstack "$*"
  local index=${1:-"0"}
  local vm="${CLUSTER}-master${index}"
  local envvar
  envvar=$(utils::to_upper "master${index}_ip")
  local ip
  local gw

  vm::create "$vm"
  ip=$(vm::exec "$vm" utils::wait_ip)
  gw=$(vm::exec "$vm" network::gateway)

  utils::replace_line_by_prefix "${DOT}/${CLUSTER}-cluster.sh" "$envvar" "=\"${ip}\""
  utils::replace_line_by_prefix "${DOT}/${CLUSTER}-cluster.sh" "DNSMASQ_IP" "=\"${gw}\""

  vm::exec "$vm" provision::master
}

orchestrate::worker() {
  dumpstack "$*"
  local index=${1:-"0"}
  local vm="${CLUSTER}-worker${index}"

  vm::create "$vm"
  vm::exec "$vm" provision::worker

  worker_ip=$(vm::exec "$vm" utils::wait_ip)

  docker_subnet=$(utils::docker_subnet "$worker_ip")
  sudo ip route replace "$docker_subnet" via $worker_ip
}
