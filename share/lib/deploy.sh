#!/bin/bash

deploy::loop() {
  kubectl delete -f "$@" 2>/dev/null
  kubectl create -f "$@"
}

deploy::addon() {
  local addon="$1"
  deploy::loop "${ADDONS_ROOT}/${addon}"
}

deploy::app() {
  local app="$1"
  deploy::loop "${APPS_ROOT}/${app}"
}
