#!/bin/bash

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

cluster::down() {
  for cid in $(vm::discover master) $(vm::discover worker); do
    vm::exec ${cid} "halt"
  done

  post::route_clean
}
