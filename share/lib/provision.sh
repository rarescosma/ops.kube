#!/bin/bash

provision::master() {
  utils::require_vm
  provision::base

  utils::template $TPL/auth_token.csv > /kube/etc/auth/token.csv
  cp -f $TPL/auth_policy.jsonl /kube/etc/auth/policy.jsonl

  provision::setup_units etcd kube-apiserver kube-controller-manager kube-scheduler
}

provision::worker() {
  utils::require_vm
  provision::base

  export POD_CIDR=$(utils::docker_subnet $MY_IP)
  export POD_BIP=$(echo "${POD_CIDR}" | sed -e "s/0\.0/0\.1/g")

  utils::template $TPL/kubelet_kubeconfig > /kube/etc/kubelet/kubeconfig

  provision::setup_units docker kubelet kube-proxy
}

provision::base() {
  utils::require_vm

  # Check connectivity - DANGER!
  while ! ping -c1 www.google.com &>/dev/null; do :; done

  # Update/upgrade + essentials
  apt update
  apt -y full-upgrade
  apt -y install curl wget ncdu htop iptables socat

  # Profile / aliases / etc.
  local rc="/root/.bashrc"
  grep -q -F '##kube' $rc || cat $DOT/templates/bashrc >> $rc

  # Link binaries
  ln -sf /kube/bin/* /usr/bin/
}

provision::setup_units() {
  for unit in "$@"; do
    utils::template "${TPL}/unit_${unit}" > /etc/systemd/system/$unit.service
  done

  systemctl daemon-reload

  for unit in "$@"; do
    systemctl enable $unit
    systemctl restart $unit || systemctl start $unit
  done
}
