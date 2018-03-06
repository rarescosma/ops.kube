#!/usr/bin/env bash

host::post() {
  dumpstack "$*"
  echo
}

host::stop() {
  dumpstack "$*"
  echo
}

host::resolvconf::start() {
  dumpstack "$*"
  local dns_ip
  dns_ip="$(utils::service_ip "$KUBE_SERVICE_CLUSTER_IP_RANGE")0"

  sudo chattr -i /etc/resolv.conf
  cat << __EOF__ | sudo tee /etc/resolv.conf
search svc.kubernetes.local
nameserver 10.0.40.1
nameserver ${dns_ip}
__EOF__
  sudo chattr +i /etc/resolv.conf
}

host::resolvconf::stop() {
  dumpstack "$*"
  sudo chattr -i /etc/resolv.conf
  cat << __EOF__ | sudo tee /etc/resolv.conf
search lan
nameserver 8.8.8.8
__EOF__
}
