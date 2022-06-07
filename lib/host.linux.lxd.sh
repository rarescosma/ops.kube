#!/usr/bin/env bash

host::prepare() {
  dumpstack "$*"

  _restore_resolvconf
  utils::wait_for_net
  _host::wait_for_lxd
}

_host::wait_for_lxd() {
  local lxd_unit

  if [ -x "$(command -v snap)" ]; then
    lxd_unit="snap.lxd.daemon"
  else
    lxd_unit="lxd"
  fi

  # restart lxd and wait for it
  sudo systemctl is-active --quiet ${lxd_unit} || {
    sudo systemctl restart ${lxd_unit}
    while true; do
      lxc list 1>/dev/null && break
      sleep 1
    done
  }
}

_mangle_resolvconf() {
  local coredns_ip
  coredns_ip="$(utils::dns_ip)"

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
nameserver ${DEFAULT_DNS}
__EOF__
  sudo chattr +i /etc/resolv.conf
}

_add_k8s_zone_to_dnsmasq() {
  local coredns_ip
  coredns_ip="$(utils::dns_ip)"
  echo -e "server=/${CLUSTER_DOMAIN}/${coredns_ip}" \
  | lxc network set "${LXD_BRIDGE}" raw.dnsmasq -
}

_setup_lb() {
  (
    cat << __EOF__
worker_processes auto;

events {
  worker_connections 768;
  multi_accept on;
}

stream {
  server {
    listen 0.0.0.0:80;
    proxy_pass workers;
    proxy_protocol on;
    proxy_protocol_timeout 2s;
  }
  upstream workers {
__EOF__
    for worker_ip in $(vm::discover worker ips); do
      echo "    server ${worker_ip}:10080 fail_timeout=2s;"
    done

    cat << __EOF__
    random;
  }
}
__EOF__
  ) | sudo tee /etc/nginx/nginx.conf
}
