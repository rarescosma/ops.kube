#!/usr/bin/env bash

MASTER_UNITS="etcd kube-apiserver kube-controller-manager kube-scheduler"
WORKER_UNITS="containerd kubelet kube-proxy masquerade"

provision::master() {
  dumpstack "$*"
  utils::export_vm

  provision::resolv_conf "$(network::gateway)"
  provision::base -skipapt

  mkdir -p /kube/konfig
  utils::template "${TPL}/konfig/kube-scheduler.yaml" > "/kube/konfig/kube-scheduler.yaml"

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

  mkdir -p /etc/cni/net.d /etc/containerd /kube/konfig

  POD_CIDR=$(network::pod_cidr "$VM_IP")
  export POD_CIDR

  local auth_dir
  auth_dir="${OUT_DIR}/auth"

  if ! test -f "$auth_dir/${VM_HOST}.pem"; then
    auth::make_cert kubelet $VM_HOST
    auth::make_kubeconfig ${VM_HOST} system:node:${VM_HOST} ${MASTER0_IP}
  fi

  if ! test -f "$auth_dir/kube-proxy.pem"; then
    auth::make_cert kube-proxy kube-proxy
    auth::make_kubeconfig kube-proxy system:kube-proxy ${MASTER0_IP}
  fi

  utils::template "${TPL}/konfig/kubelet.yaml" > "/kube/konfig/${VM_HOST}.yaml"
  utils::template "${TPL}/konfig/kube-proxy.yaml" > "/kube/konfig/kube-proxy.yaml"

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
    apt -y install \
      curl wget iptables software-properties-common ncdu htop \
      socat conntrack net-tools golang-cfssl
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
