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

  systemctl stop kubelet || systemctl stop kubelet_single
  docker rm -f "$(docker ps -a -q)" 2>/dev/null || true
  halt
}

cluster::configure() {
  dumpstack "$*"
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
  cp -f "${DOT}/cluster.sh.empty" "${DOT}/${CLUSTER}-cluster.sh"
}
