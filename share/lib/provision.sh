#!/usr/bin/env bash

provision::master() {
  utils::export_vm
  provision::base -skipapt

  utils::template "$TPL/auth_token.csv" > /kube/etc/auth/token.csv
  cp -f "$TPL/auth_policy.jsonl" /kube/etc/auth/policy.jsonl

  provision::setup_units ${MASTER_UNITS}
}

provision::worker() {
  utils::export_vm
  provision::base -skipapt

  POD_CIDR=$(utils::docker_subnet "$VM_IP")
  export POD_CIDR
  POD_BIP=${POD_CIDR//0.0/0.1}
  # POD_BIP=$(echo "${POD_CIDR}" | sed -e "s/0\.0/0\.1/g")
  export POD_BIP

  utils::template "$TPL/kubelet_kubeconfig" > /kube/etc/kubelet/kubeconfig

  provision::setup_units ${WORKER_UNITS}
}

provision::base() {
  utils::export_vm

  # Check connectivity - DANGER!
  while ! ping -c1 www.google.com &>/dev/null; do :; done

  if [[ "$1" != "-skipapt" ]]; then
    # Update/upgrade + essentials
    apt update
    apt -y full-upgrade
    apt -y install curl wget ncdu htop iptables socat
  fi

  # Profile / aliases / etc.
  local rc="/root/.bashrc"
  grep -q -F '##kube' "$rc" || cat "$DOT/templates/bashrc" >> "$rc"

  # Link binaries
  ln -sf "${KUBE_PV}/bin/"* /usr/bin/
}

provision::setup_units() {
  for unit in "$@"; do
    utils::template "${TPL}/unit_${unit}" > "/etc/systemd/system/${unit}.service"
  done

  systemctl daemon-reload

  for unit in "$@"; do
    systemctl enable "$unit"
    systemctl restart "$unit" || systemctl start "$unit"
  done
}
