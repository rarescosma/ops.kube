#!/usr/bin/env bash

addon_tpl() {
  local addon
  addon="${1}"
  export KUBE_DNS_IP="$(utils::service_ip "$KUBE_SERVICE_CLUSTER_IP_RANGE")00"
  export KUBE_DNS_DOMAIN="kubernetes.local"

  utils::template "$TPL/addons/${addon}.yaml.tpl" \
  | tee "$TPL/addons/${addon}.yaml" \
  | kubectl apply -f -
}

addon() {
  local addon
  addon="${1}"
  kubectl apply \
    -f "$TPL/addons/${addon}.yaml"
}

addon::essentials() {
  addon_tpl coredns
  addon registry
  addon ingress
}
