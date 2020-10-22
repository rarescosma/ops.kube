#!/usr/bin/env bash

cluster::stop() {
  dumpstack "$*"
  for mid in $(vm::discover "$CLUSTER" master); do
    vm::exec "${mid}" "halt" &
  done

  for wid in  $(vm::discover "$CLUSTER" worker); do
    vm::exec "${wid}" cluster::stop_worker &
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
  utils::template "${TPL}/auth/kubeconfig_admin"
}

cluster::master() {
  # shellcheck source=/dev/null
  source "${DOT}/${CLUSTER}-cluster.sh"
  echo "http://${MASTER0_IP}:8080"
}

cluster::clean() {
  dumpstack "$*"
  vm::destroy "$(vm::discover "$CLUSTER" master)"
  vm::destroy "$(vm::discover "$CLUSTER" worker)"
  echo > "${OUT_DIR}/env"
}
