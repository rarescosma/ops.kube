#!/usr/bin/env bash

orchestrate::master() {
  dumpstack "$*"
  local vm_name vm envvar
  vm_name="master0"
  vm="$vm_name-${CLUSTER}"
  envvar=$(utils::to_upper "${vm_name}_ip")

  local ip gw api_ip dns_ip

  vm::create "$vm"
  ip=$(vm::exec "$vm" utils::wait_for_ip)
  gw=$(vm::exec "$vm" network::gateway)
  api_ip="$(utils::service_ip "$SERVICE_CIDR").1"
  dns_ip="$(dns::get_ip)"

  utils::replace_line_by_prefix "${OUT_DIR}/env" "$envvar" "=\"${ip}\""
  utils::replace_line_by_prefix "${OUT_DIR}/env" "DNSMASQ_IP" "=\"${gw}\""
  utils::replace_line_by_prefix "${OUT_DIR}/env" "KUBE_API_IP" "=\"${api_ip}\""
  utils::replace_line_by_prefix "${OUT_DIR}/env" "KUBE_DNS_IP" "=\"${dns_ip}\""

  vm::exec "$vm" provision::master
  vm::exec "$vm" provision::worker is_master
}

orchestrate::workers() {
  local worker_wm
  for x in $(seq 0 $((VM_NUM_WORKERS-1))); do
    worker_vm="worker${x}-${CLUSTER}"
    orchestrate::vm "$worker_vm" &
  done
  wait
}

orchestrate::vm() {
  dumpstack "$*"
  local vm=${1}

  vm::create "$vm"
  vm::exec "$vm" provision::worker

  worker_ip=$(vm::exec "$vm" utils::wait_for_ip)

  pod_cidr=$(network::pod_cidr "$worker_ip")
  sudo ip route replace "$pod_cidr" via $worker_ip
}
