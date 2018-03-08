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
}

host::resolvconf::start() {
  dumpstack "$*"
  local dns_ip
  dns_ip="$(utils::service_ip "$KUBE_SERVICE_CLUSTER_IP_RANGE")0"

  sudo chattr -i /etc/resolv.conf
  cat << __EOF__ | sudo tee /etc/resolv.conf
search svc.kubernetes.local
nameserver 10.32.0.10
nameserver ${dns_ip}
__EOF__
  sudo chattr +i /etc/resolv.conf
}

host::stop() {
  dumpstack "$*"
  host::resolvconf::stop
}

host::resolvconf::stop() {
  dumpstack "$*"
  sudo chattr -i /etc/resolv.conf
  cat << __EOF__ | sudo tee /etc/resolv.conf
search lan
nameserver 8.8.8.8
__EOF__
}
