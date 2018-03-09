#!/usr/bin/env bash

addon::coredns() {
  export KUBE_DNS_IP="$(utils::service_ip "$KUBE_SERVICE_CLUSTER_IP_RANGE")00"
  export KUBE_DNS_DOMAIN="kubernetes.local"

  utils::template "$TPL/addons/coredns.yaml.tpl" \
  | sed 's/: true/: "true"/g' \
  | tee "$TPL/addons/coredns.yaml" \
  | kubectl apply -f -
}
