#!/usr/bin/env bash

addon_tpl() {
  local addon
  addon="${1}"
  export KUBE_DNS_IP="$(dns::get_ip)"
  export ASSCAPED_LXD_DOMAIN="${LXD_DOMAIN/\./\\.}"

  mkdir -p "${OUT_DIR}/.manifests"
  {
    cat "${TPL}/addons/sys-ns.yaml"
    utils::template "$TPL/addons/${addon}.yaml.tpl" |
      tee "${OUT_DIR}/.manifests/${addon}.yaml"
  } | kubectl apply -f -
}

addon() {
  local addon
  addon="${1}"
  kubectl apply \
    -f "${TPL}/addons/sys-ns.yaml" \
    -f "${TPL}/addons/${addon}.yaml"
}

addon::sys() {
  addon registry
  addon_tpl coredns
  addon_tpl ingress-nginx
}
