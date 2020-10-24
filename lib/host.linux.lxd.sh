#!/usr/bin/env bash

host::prepare() {
  dumpstack "$*"
  local lxd_unit

  if [ -x "$(command -v snap)" ]; then
    lxd_unit="snap.lxd.daemon"
  else
    lxd_unit="lxd"
  fi

  # restart lxd and wait for it
  sudo systemctl is-active --quiet ${lxd_unit} || {
    sudo killall dnsmasq || true
    sudo systemctl restart ${lxd_unit}
    while true; do
      lxc list 1>/dev/null && break
      sleep 1
    done
  }
}

host::start() {
  _restore_resolvconf
  utils::wait_for_net
  orchestrate::main
  network::cycle
  _mangle_resolvconf
}

host::stop() {
  dumpstack "$*"
  _restore_resolvconf
  cluster::stop
}

_mangle_resolvconf() {
  local coredns_ip
  coredns_ip="$(utils::service_ip "$SERVICE_CIDR").100"

  sudo chattr -i /etc/resolv.conf
  cat << __EOF__ | sudo tee /etc/resolv.conf
search svc.${CLUSTER_DOMAIN} ${LXD_DOMAIN}
nameserver ${coredns_ip}
__EOF__
  sudo chattr +i /etc/resolv.conf
}

_restore_resolvconf() {
  sudo chattr -i /etc/resolv.conf
  cat << __EOF__ | sudo tee /etc/resolv.conf
nameserver 8.8.8.8
__EOF__
}

_add_k8s_zone_to_dnsmasq() {
  local coredns_ip
  coredns_ip="$(utils::service_ip "$SERVICE_CIDR").100"
  echo -e "server=/${CLUSTER_DOMAIN}/${coredns_ip}" \
  | lxc network set "${LXD_BRIDGE}" raw.dnsmasq -
}
