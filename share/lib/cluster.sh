#!/usr/bin/env bash

cluster::stop() {
  for mid in $(vm::discover master); do
    vm::exec "${mid}" "halt" &
  done

  for wid in  $(vm::discover worker); do
    vm::exec "${wid}" cluster::stop_worker &
  done

  wait
}

cluster::stop_worker() {
  vm::assert_vm

  systemctl stop kubelet || systemctl stop kubelet_single
  docker rm -f "$(docker ps -a -q)"
  halt
}

cluster::configure() {
  # Source cluster.sh again to capture MASTER0_IP
  # shellcheck source=/dev/null
  source "${DOT}/cluster.sh"
  local kc='kubectl config'

  $kc set-cluster kube-cluster-name \
  --certificate-authority="${DOT}/etc/tls/ca.pem" \
  --embed-certs=true \
  --server="https://${MASTER0_IP}:6443"

  $kc set-credentials admin --token "${SECRET_TOKEN}"

  $kc set-context default-context \
  --cluster=kube-cluster-name \
  --user=admin

  $kc use-context default-context
}

cluster::clean() {
  vm::destroy "$(vm::discover master)"
  vm::destroy "$(vm::discover worker)"
  cp -f "${DOT}/cluster.sh.empty" "${DOT}/cluster.sh"
}
