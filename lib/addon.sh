#!/usr/bin/env bash

addon() {
  local addon
  addon="${1}"

  {
    if test -f "$TPL/addons/${addon}.yaml.tpl"; then
      export KUBE_DNS_IP="$(dns::get_ip)"
      export ASSCAPED_LXD_DOMAIN="${LXD_DOMAIN/\./\\.}"
      mkdir -p "$OUT_DIR/.manifests"
      utils::template "$TPL/addons/${addon}.yaml.tpl" \
        | tee "$OUT_DIR/.manifests/${addon}.yaml"
    else
      cat "$TPL/addons/${addon}.yaml"
    fi
  } | kubectl apply -f -
}

addon::sys() {
  addon kubelet-auth
  addon coredns
}
