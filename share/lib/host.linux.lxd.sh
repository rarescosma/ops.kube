#!/usr/bin/env bash

host::restart_lxd() {
  dumpstack "$*"
  # restart lxd and wait for it
  sudo systemctl is-active --quiet lxd || {
    sudo killall dnsmasq || true
    sudo systemctl restart lxd
    while true; do
      lxc list 1>/dev/null && break
      sleep 1
    done
  }
}

host::prepare() {
  dumpstack "$*"
  host::restart_lxd
}

host::post() {
  dumpstack "$*"
  cluster::configure
  host::resolvconf::start
  addon::essentials
}

host::resolvconf::start() {
  dumpstack "$*"
  local dns_ip
  dns_ip="$(utils::service_ip "$KUBE_SERVICE_CLUSTER_IP_RANGE")00"

  sudo chattr -i /etc/resolv.conf /etc/resolv.dnsmasq.forward
  cat << __EOF__ | sudo tee /etc/resolv.conf
search svc.kubernetes.local
nameserver ${DNSMASQ_IP}
__EOF__

  cat << __EOF__ | sudo tee /etc/resolv.dnsmasq.forward
nameserver 8.8.8.8
__EOF__
  sudo chattr +i /etc/resolv.conf /etc/resolv.dnsmasq.forward
}

host::stop() {
  dumpstack "$*"
  host::resolvconf::stop
}

host::resolvconf::stop() {
  dumpstack "$*"
  sudo chattr -i /etc/resolv.conf
  cat << __EOF__ | sudo tee /etc/resolv.conf
nameserver 8.8.8.8
__EOF__
}
