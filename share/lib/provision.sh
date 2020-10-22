#!/usr/bin/env bash

provision::master() {
  dumpstack "$*"
  utils::export_vm

  local dns_servers
  dns_servers="8.8.8.8"
  if [[ "$VM_ENGINE" == "lxd" ]]; then
    dns_servers="$(network::gateway)"
  fi

  provision::resolv_conf ${dns_servers}

  provision::base -skipapt

  cp -f "$TPL/auth_policy.jsonl" /kube/etc/auth/policy.jsonl
  utils::template "${TPL}/auth/token.csv" > "${OUT_DIR}/auth/token.csv"

  provision::setup_units ${MASTER_UNITS}
}

provision::worker() {
  dumpstack "$*"
  utils::export_vm

  local dns_servers
  dns_servers="8.8.8.8"
  if [[ "$VM_ENGINE" == "lxd" ]]; then
    dns_servers="$(network::gateway)"
  fi

  provision::resolv_conf ${dns_servers}

  provision::base -skipapt

  if [ ! -z ${USE_SYSTEM_DOCKER+x} ]; then
      provision::install_docker
  fi

  POD_CIDR=$(utils::docker_subnet "$VM_IP")
  export POD_CIDR
  POD_BIP=${POD_CIDR//0.0/0.1}
  export POD_BIP

  utils::template "${TPL}/auth/kubeconfig_kubelet" > "${OUT_DIR}/auth/kubelet_kubeconfig"

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
  local unit_dir out_dir
  unit_dir="${TPL}/units"
  out_dir="${OUT_DIR}/units"
  mkdir -p "${out_dir}"

  for unit in "$@"; do
    utils::template "${unit_dir}/${unit}" > "${out_dir}/${unit}.service"
    ln -sf "${out_dir}/${unit}.service" /etc/systemd/system/
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
