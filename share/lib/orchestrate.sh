#!/usr/bin/env bash

orchestrate::master() {
  local index=${1:-"0"}
  local vm="master${index}"
  local envvar=$(utils::to_upper ${vm}_ip)
  local ip

  vm::launch $vm
  ip=$(vm::exec $vm utils::wait_ip)

  utils::replace_line_by_prefix $DOT/cluster.sh $envvar "=\"${ip}\""

  vm::exec $vm provision::master
}

orchestrate::worker() {
  local index=${1:-"0"}
  local vm="worker${index}"

  vm::launch $vm
  vm::exec $vm provision::worker
}
