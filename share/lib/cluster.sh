#!/usr/bin/env bash

cluster::destroy() {
  vm::destroy $(vm::discover master)
  vm::destroy $(vm::discover worker)
  post::route_clean
  cp -f "${DOT}/cluster.sh.empty" "${DOT}/cluster.sh"
}

cluster::up() {
  orchestrate
  post
}

cluster::stop_worker() {
  vm::assert_vm

  systemctl stop kubelet || systemctl stop kubelet_single
  docker rm -f $(docker ps -a -q)
  halt
}

cluster::down() {
  for mid in $(vm::discover master); do
    vm::exec ${mid} "halt" &
  done

  for wid in  $(vm::discover worker); do
    vm::exec ${wid} cluster::stop_worker &
  done

  wait
  post::route_clean
}
