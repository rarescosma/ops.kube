#!/usr/bin/env bash

host::prepare() {
  # Flush all iptables rules
  network::flush_iptables
  sudo cat /etc/iptables.up.rules | sudo iptables-restore

  # Reboot the docker daemon
  sudo systemctl restart docker
}

host::post() {
  host::resolvconf::start

  # Forward TLS to the ingress
  if hash forward_ports.sh 2>/dev/null; then
    forward_ports.sh 443
  fi
}

host::resolvconf::start() {
  sudo chattr -i /etc/resolv.conf
  cat << __EOF__ | sudo tee /etc/resolv.conf
search svc.kubernetes.local
nameserver 10.32.0.10
nameserver 10.0.40.130
__EOF__
  sudo chattr +i /etc/resolv.conf
}

host::stop() {
  host::resolvconf::stop
}

host::resolvconf::stop() {
  sudo chattr -i /etc/resolv.conf
  cat << __EOF__ | sudo tee /etc/resolv.conf
search lan
nameserver 8.8.8.8
nameserver 8.8.4.4
__EOF__
}
