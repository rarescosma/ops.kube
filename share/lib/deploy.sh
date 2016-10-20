#!/bin/bash

deploy::replace() {
  kubectl replace -f "$@"
}

deploy::loop() {
  kubectl delete -f "$@" 2>/dev/null
  kubectl create -f "$@"
}

deploy::replace_addon() {
  local addon="$1"
  deploy::replace "${ADDONS_ROOT}/${addon}"
}

deploy::recreate_addon() {
  local addon="$1"
  deploy::loop "${ADDONS_ROOT}/${addon}"
}
