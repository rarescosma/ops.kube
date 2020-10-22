#!/usr/bin/env bash

orchestrate::master() {
  dumpstack "$*"
  local index=${1:-"0"}
  local vm="${CLUSTER}-master${index}"
  local envvar
  envvar=$(utils::to_upper "master${index}_ip")
  local ip gw api_ip dns_ip

  vm::create "$vm"
  ip=$(vm::exec "$vm" utils::wait_ip)
  gw=$(vm::exec "$vm" network::gateway)
  api_ip="$(utils::service_ip "$SERVICE_CIDR")"
  dns_ip="$(utils::service_ip "$SERVICE_CIDR")00"

  utils::replace_line_by_prefix "${OUT_DIR}/env" "$envvar" "=\"${ip}\""
  utils::replace_line_by_prefix "${OUT_DIR}/env" "DNSMASQ_IP" "=\"${gw}\""
  utils::replace_line_by_prefix "${OUT_DIR}/env" "KUBE_API_IP" "=\"${api_ip}\""
  utils::replace_line_by_prefix "${OUT_DIR}/env" "KUBE_DNS_IP" "=\"${dns_ip}\""

  vm::exec "$vm" provision::master
}

orchestrate::worker() {
  dumpstack "$*"
  local index=${1:-"0"}
  local vm="${CLUSTER}-worker${index}"

  vm::create "$vm"
  vm::exec "$vm" provision::worker

  worker_ip=$(vm::exec "$vm" utils::wait_ip)

  pod_cidr=$(network::pod_cidr "$worker_ip")
  sudo ip route replace "$pod_cidr" via $worker_ip
}
