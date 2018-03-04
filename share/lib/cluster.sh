#!/usr/bin/env bash

cluster::stop() {
  dumpstack "$*"
  for mid in $(vm::discover master); do
    vm::exec "${mid}" "halt" &
  done

  for wid in  $(vm::discover worker); do
    vm::exec "${wid}" cluster::stop_worker &
  done

  wait
}

cluster::stop_worker() {
  dumpstack "$*"
  vm::assert_vm

  systemctl stop kubelet || systemctl stop kubelet_single
  docker rm -f "$(docker ps -a -q)" 2>/dev/null || true
  halt
}

cluster::configure() {
  dumpstack "$*"
  # Source cluster.sh again to capture MASTER0_IP
  # shellcheck source=/dev/null
  source "${DOT}/${CLUSTER}-cluster.sh"
  local kc='kubectl config'

  $kc set-cluster "${CLUSTER}" \
  --certificate-authority="${DOT}/etc/tls/${CLUSTER}/ca.pem" \
  --embed-certs=true \
  --server="https://${MASTER0_IP}:6443"

  $kc set-credentials "${CLUSTER}-root" --token "${SECRET_TOKEN}"

  $kc set-context "${CLUSTER}" \
  --cluster="${CLUSTER}" \
  --user="${CLUSTER}-root"

  $kc use-context "${CLUSTER}"
}

cluster::clean() {
  dumpstack "$*"
  vm::destroy "$(vm::discover master)"
  vm::destroy "$(vm::discover worker)"
  cp -f "${DOT}/cluster.sh.empty" "${DOT}/${CLUSTER}-cluster.sh"
}
