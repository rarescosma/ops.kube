#!/usr/bin/env bash

cluster::stop() {
  dumpstack "$*"
  for mid in $(vm::discover master); do
    lxc stop -f "${mid}" || true
  done

  for wid in  $(vm::discover worker); do
    lxc stop -f "${wid}" || true
  done

  wait
}

cluster::stop_worker() {
  dumpstack "$*"
  vm::assert_vm

  systemctl stop kubelet
  systemctl stop containerd
  halt
}

cluster::configure() {
  dumpstack "$*"
  load_env "${OUT_DIR}/env" "/kube/env"
  mkdir -p "${HOME}/.kube"
  sed "s/127\.0\.0\.1/${MASTER0_IP}/g" ${OUT_DIR}/auth/admin.kubeconfig > "${HOME}/.kube/${CLUSTER}"
}

cluster::master() {
  # shellcheck source=/dev/null
  source "${DOT}/${CLUSTER}-cluster.sh"
  echo "http://${MASTER0_IP}:8080"
}

cluster::clean() {
  dumpstack "$*"
  vm::destroy "$(vm::discover master)"
  vm::destroy "$(vm::discover worker)"
  echo > "${OUT_DIR}/env"
}
