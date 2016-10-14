#!/bin/bash

post::configure_kc() {
  # Source env.sh again to capture the master0 IP
  source $DOT/env.sh

  kubectl config set-cluster kube-cluster-name \
    --certificate-authority=$DOT/etc/tls/ca.pem \
    --embed-certs=true \
    --server=https://${MASTER0_IP}:6443

  kubectl config set-credentials admin --token ${SECRET_TOKEN}

  kubectl config set-context default-context \
    --cluster=kube-cluster-name \
    --user=admin

  kubectl config use-context default-context
}

post::route_clean() {
  for X in $(seq 1 255); do
    sudo route del -net "172.${X}.0.0/16" &>/dev/null &
  done
  sudo route del -net $KUBE_SERVICE_CLUSTER_IP_RANGE &>/dev/null &
  wait
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
