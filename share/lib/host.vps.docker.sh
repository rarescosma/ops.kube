#!/usr/bin/env bash

host::prepare() {
  # Stop docker
  sudo systemctl stop docker
  sudo pkill -f docker
  sudo ifconfig docker0 down
  sudo brctl delbr docker0

  # Flush all iptables rules
  network::flush_iptables
  sudo iptables-restore < /etc/iptables.up.rules

  # Reboot the docker daemon
  sudo systemctl start docker
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
