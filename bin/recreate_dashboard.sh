#!/bin/bash

set -o nounset
set -o pipefail

SCRIPTPATH=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )
ADDONS_ROOT="${SCRIPTPATH}/../addons"

kubectl delete -f $ADDONS_ROOT/dashboard/dashboard-controller.yaml
kubectl delete -f $ADDONS_ROOT/dashboard/dashboard-service.yaml


kubectl create -f $ADDONS_ROOT/dashboard/dashboard-service.yaml
kubectl create -f $ADDONS_ROOT/dashboard/dashboard-controller.yaml
