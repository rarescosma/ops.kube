#!/usr/bin/env bash

MASTER_UNITS="etcd kube-apiserver kube-controller-manager kube-scheduler"
WORKER_UNITS="containerd kubelet kube-proxy masquerade"

provision::master() {
  dumpstack "$*"
  utils::export_vm

  provision::resolv_conf "$(network::gateway)"
  provision::base -skipapt

  utils::template "${TPL}/auth/token.csv" > "${OUT_DIR}/auth/token.csv"

  provision::setup_units ${MASTER_UNITS}
}

provision::worker() {
  dumpstack "$*"
  utils::export_vm

  if [[ "$1" == "is_master" ]]; then
    export KUBELET_ARGS="--register-with-taints=node-role.kubernetes.io/master=master:NoSchedule --node-labels=node_role=master"
  fi

  provision::resolv_conf "$(network::gateway)"
  provision::base -skipapt

  POD_CIDR=$(network::pod_cidr "$VM_IP")
  export POD_CIDR

  utils::template "${TPL}/auth/kubeconfig_kubelet" > "${OUT_DIR}/auth/kubelet_kubeconfig"

  mkdir -p /etc/cni/net.d /etc/containerd
  utils::template "${TPL}/etc/cni-10-bridge.conf" > "/etc/cni/net.d/10-bridge.conf"
  utils::template "${TPL}/etc/cni-99-loopback.conf" > "/etc/cni/net.d/99-loopback.conf"
  utils::template "${TPL}/etc/containerd-config.toml" > "/etc/containerd/config.toml"

  provision::setup_units ${WORKER_UNITS}

  unset KUBELET_ARGS
}

provision::resolv_conf() {
  dumpstack "$*"
  local server rc
  rc="/etc/resolv.conf"

  rm -f "$rc" && touch "$rc"
  for server in $*; do
    echo "nameserver $server" >> "$rc"
  done
  chmod -w "$rc"
}

provision::base() {
  dumpstack "$*"
  utils::export_vm

  utils::wait_for_net

  if [[ "$1" != "-skipapt" ]]; then
    # Update/upgrade + essentials
    apt update
    apt -y full-upgrade
    apt -y install curl wget iptables software-properties-common ncdu htop socat conntrack net-tools
  fi

  # Profile / aliases / etc.
  local rc="/root/.bashrc"
  grep -q -F '##kube' "$rc" || cat "$DOT/templates/bashrc" >> "$rc"

  # Binaries
  mkdir -p /opt/cni/bin
  ln -sf /kube/bin/* /usr/bin/
  ln -sf /kube/bin/* /opt/cni/bin/
}

provision::setup_units() {
  dumpstack "$*"
  local unit_dir
  unit_dir="${TPL}/units"

  for unit in "$@"; do
    rm -f "/etc/systemd/system/${unit}.service"
    utils::template "${unit_dir}/${unit}" > "/etc/systemd/system/${unit}.service"
  done

  systemctl daemon-reload

  for unit in "$@"; do
    systemctl enable "$unit"
    systemctl restart "$unit" || systemctl start "$unit"
  done
}
