#!/bin/bash

orchestrate::master() {
  local index=${1:-"0"}
  local vm="master${index}"
  local envvar=$(utils::to_upper ${vm}_ip)
  local ip

  (lxc launch $LXC_IMG $vm --profile $LXC_PROFILE || lxc start $vm) 2>/dev/null
  ip=$(lxc::exec $vm utils::wait_ip)

  utils::replace_line_by_prefix $DOT/env.sh $envvar "=\"${ip}\""
}

orchestrate::masters() {
  orchestrate::master 0
  orchestrate::master 1

  lxc::exec master0 provision::master
  lxc::exec master1 provision::master
}

orchestrate::worker() {
  local index=${1:-"0"}
  local vm="worker${index}"

  (lxc launch $LXC_IMG $vm --profile $LXC_PROFILE || lxc start $vm) 2>/dev/null

  lxc::exec $vm provision::worker
}
