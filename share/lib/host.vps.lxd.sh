#!/usr/bin/env bash

host::prepare() {
  echo "Prepd!"
}

host::normal_prepare() {
  # Flush all iptables rules
  network::flush_iptables
  sudo iptables-restore < /etc/iptables.up.rules

  # Make sure we're masquerading the network interface
  sudo iptables -t nat -D POSTROUTING -o ${VM_IFACE} -j MASQUERADE
  sudo iptables -t nat -A POSTROUTING -o ${VM_IFACE} -j MASQUERADE

  # Make sure overlay is loaded
  sudo modprobe overlay
}

host::post() {
  if hash forward_ports.sh 2>/dev/null; then
    forward_ports.sh 443
  fi
}

host::stop() {
  echo "host::stop()"
}
