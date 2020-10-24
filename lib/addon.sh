#!/usr/bin/env bash

addon_tpl() {
  local addon
  addon="${1}"
  export KUBE_DNS_IP="$(utils::service_ip "$SERVICE_CIDR").100"
  export KUBE_INGRESS_IP="$(utils::service_ip "$SERVICE_CIDR").200"
  export KUBE_DNS_DOMAIN="kubernetes.local"

  mkdir -p "$TPL/addons/.out"

  utils::template "$TPL/addons/${addon}.yaml.tpl" \
  | tee "$TPL/addons/.out/${addon}.yaml" \
  | kubectl apply -f -
}

addon() {
  local addon
  addon="${1}"
  kubectl apply \
    -f "${TPL}/addons/sys-ns.yaml" \
    -f "${TPL}/addons/${addon}.yaml"
}

addon::essentials() {
  addon registry
  addon_tpl coredns
  addon_tpl ingress
}
