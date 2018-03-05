#!/usr/bin/env bash

host::restart_lxd() {
  dumpstack "$*"
  # restart lxd and wait for it
  sudo killall dnsmasq || true
  sudo systemctl restart lxd
  while true; do
    lxc list 1>/dev/null && break
    sleep 1
  done
}

host::post() {
  dumpstack "$*"
  host::resolvconf::start
}

host::resolvconf::start() {
  dumpstack "$*"
  sudo chattr -i /etc/resolv.conf
  cat << __EOF__ | sudo tee /etc/resolv.conf
search svc.kubernetes.local
nameserver 10.32.0.10
nameserver 10.0.40.1
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
nameserver 192.168.0.1
nameserver 8.8.8.8
__EOF__
}
