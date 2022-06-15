#!/usr/bin/env bash

dns::get_ip() {
  echo "$(utils::service_ip "$SERVICE_CIDR").100"
}

dns::wait_for_coredns() {
  dumpstack
  local dns_ip=$(dns::get_ip)
  echo -n "Waiting for CoreDNS"
  while ! dig svc.${CLUSTER_DOMAIN} +timeout=1 @${dns_ip} >/dev/null 2>&1; do
    echo -n "."
  done
  echo
}

dns::configure_resolvconf() {
  local coredns_ip
  coredns_ip="$(dns::get_ip)"

  sudo chattr -i /etc/resolv.conf
  cat << __EOF__ | sudo tee /etc/resolv.conf
search svc.${CLUSTER_DOMAIN} ${LXD_DOMAIN}
nameserver ${coredns_ip}
__EOF__
  sudo chattr +i /etc/resolv.conf
}

dns::restore_resolvconf() {
  sudo chattr -i /etc/resolv.conf
  cat << __EOF__ | sudo tee /etc/resolv.conf
nameserver ${DEFAULT_DNS}
__EOF__
  sudo chattr +i /etc/resolv.conf
}

dns::configure_lxc_network() {
  local coredns_ip
  coredns_ip="$(dns::get_ip)"
  echo -e "server=/${CLUSTER_DOMAIN}/${coredns_ip}" \
  | lxc network set "${LXD_BRIDGE}" raw.dnsmasq -
}
