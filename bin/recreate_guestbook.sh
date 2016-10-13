#!/bin/bash

set -o nounset
set -o pipefail

SCRIPTPATH=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )
APPS_ROOT="${SCRIPTPATH}/../apps"

kubectl delete -f $APPS_ROOT/guestbook/all-in-one/guestbook-all-in-one.yaml
kubectl create -f $APPS_ROOT/guestbook/all-in-one/guestbook-all-in-one.yaml
