#!/usr/bin/env bash

provision::master() {
  dumpstack "$*"
  utils::export_vm

  provision::base -skipapt

  utils::template "$TPL/auth_token.csv" > /kube/etc/auth/token.csv
  cp -f "$TPL/auth_policy.jsonl" /kube/etc/auth/policy.jsonl

  local dns_servers
  dns_servers="8.8.8.8"
  if [[ "$VM_ENGINE" == "lxd" ]]; then
    dns_servers="$(ip route | grep default | cut -d" " -f3) 8.8.8.8"
  fi

  provision::resolv_conf ${dns_servers}
  provision::setup_units ${MASTER_UNITS}
}

provision::worker() {
  dumpstack "$*"
  utils::export_vm

  provision::base -skipapt

  if [ ! -z ${USE_SYSTEM_DOCKER+x} ]; then
      provision::install_docker
  fi

  POD_CIDR=$(utils::docker_subnet "$VM_IP")
  export POD_CIDR
  POD_BIP=${POD_CIDR//0.0/0.1}
  export POD_BIP

  utils::template "$TPL/kubeconfig_kubelet" > /kube/etc/kubelet/kubeconfig

  local dns_servers
  dns_servers="8.8.8.8"
  if [[ "$VM_ENGINE" == "lxd" ]]; then
    dns_servers="8.8.8.8 $(ip route | grep default | cut -d" " -f3)"
  fi

  provision::resolv_conf ${dns_servers}
  provision::setup_units ${WORKER_UNITS}
}

provision::install_docker() {
  dumpstack "$*"
  curl -fsSL https://download.docker.com/linux/ubuntu/gpg | apt-key add -
  add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"
  apt update
  apt -y install docker-ce
}

provision::base() {
  dumpstack "$*"
  utils::export_vm

  # Check connectivity - DANGER!
  while ! ping -c1 www.google.com &>/dev/null; do :; done

  if [[ "$1" != "-skipapt" ]]; then
    # Update/upgrade + essentials
    apt update
    apt -y full-upgrade
    apt -y install curl wget iptables software-properties-common ncdu htop socat
  fi

  # Profile / aliases / etc.
  local rc="/root/.bashrc"
  grep -q -F '##kube' "$rc" || cat "$DOT/templates/bashrc" >> "$rc"

  # Link binaries
  ln -sf "/pv/kube/bin/"* /usr/bin/
}

provision::setup_units() {
  dumpstack "$*"

  export KUBE_SERVICE_CLUSTER_IP="$(utils::service_ip "$KUBE_SERVICE_CLUSTER_IP_RANGE")"
  export KUBE_DNS_IP="$(utils::service_ip "$KUBE_SERVICE_CLUSTER_IP_RANGE")00"

  for unit in "$@"; do
    utils::template "${TPL}/unit_${unit}" > "/etc/systemd/system/${unit}.service"
  done

  systemctl daemon-reload

  for unit in "$@"; do
    systemctl enable "$unit"
    systemctl restart "$unit" || systemctl start "$unit"
  done
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
