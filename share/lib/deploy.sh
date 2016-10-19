#!/bin/bash

deploy::apply() {
  kubectl apply -f "$@"
}

deploy::loop() {
  kubectl delete -f "$@" 2>/dev/null
  kubectl create -f "$@"
}

deploy::apply_addon() {
  local addon="$1"
  deploy::apply "${ADDONS_ROOT}/${addon}"
}

deploy::recreate_addon() {
  local addon="$1"
  deploy::loop "${ADDONS_ROOT}/${addon}"
}

deploy::apply_app() {
  local app="$1"
  deploy::apply "${APPS_ROOT}/${app}"
}

deploy::recreate_app() {
  local app="$1"
  deploy::loop "${APPS_ROOT}/${app}"
}
