#!/bin/bash

post::configure_kc() {
  # Source cluster.sh again to capture MASTER0_IP
  source "${DOT}/cluster.sh"
  local kc='kubectl config'

  $kc set-cluster kube-cluster-name \
  --certificate-authority="${DOT}/etc/tls/ca.pem" \
  --embed-certs=true \
  --server="https://${MASTER0_IP}:6443"

  $kc set-credentials admin --token "${SECRET_TOKEN}"

  $kc set-context default-context \
  --cluster=kube-cluster-name \
  --user=admin

  $kc use-context default-context
}

post::route_clean() {
  for subnet in $(seq 1 255); do
    sudo route del -net "172.${subnet}.0.0/16" &>/dev/null &
  done
  wait
  sudo route del -net $KUBE_SERVICE_CLUSTER_IP_RANGE &>/dev/null
}

post::route_add() {
  local docker_subnet

  # Find all worker IPs
  for worker_ip in $(vm::discover_workers); do
    docker_subnet=$(utils::docker_subnet $worker_ip)
    sudo route del -net $docker_subnet &>/dev/null
    sudo route add -net $docker_subnet gw $worker_ip

    # Proxy services thru the first found worker
    if [ -z ${proxy_worker+x} ]; then
      sudo route add -net $KUBE_SERVICE_CLUSTER_IP_RANGE gw $worker_ip
      proxy_worker="done"
    fi
  done
}
