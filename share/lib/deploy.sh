#!/usr/bin/env bash

deploy::replace_addon() {
  local addon="$1"
  kubectl replace -f "${ADDONS_ROOT}/${addon}"
}

deploy::apply_addon() {
  local addon="$1"
  kubectl apply -f "${ADDONS_ROOT}/${addon}"
}

deploy::recreate_addon() {
  local addon="$1"
  kubectl delete -f "${ADDONS_ROOT}/${addon}" 2>/dev/null
  kubectl create -f "${ADDONS_ROOT}/${addon}"
}
