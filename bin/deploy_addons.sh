#!/bin/bash

set -o nounset
set -o pipefail

SCRIPTPATH=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )
ADDONS_ROOT="${SCRIPTPATH}/../addons"

addons::kc() {
  local action=$1
  shift
  kubectl $action -f "${ADDONS_ROOT}/$@"
}

addons::loop() {
  kubectl delete -f "${ADDONS_ROOT}/$@"
  kubectl create -f "${ADDONS_ROOT}/$@"
}

# Docker Proxy
# addons::loop docker-registry/docker-registry-daemonset.yaml
# sleep 3

# KubeDNS
addons::loop dns/kubedns-deployment.yaml
addons::loop dns/kubedns-service.yaml

# Dashboard
addons::loop dashboard/dashboard-controller.yaml
addons::loop dashboard/dashboard-service.yaml
