#!/usr/bin/env bash

ROOT=${HOME}/kube/${CLUSTER}/state

if [[ -z "$1" ]]; then
    echo -e "pass me a namespace"
    exit 100
fi
namespace="$1"

while read -r resource
do
    echo "  scanning resource '${resource}'"
    while read -r item x
    do
        mkdir -p "${ROOT}/${resource}"
        echo "    exporting item '${item}'"
        kubectl get "$resource" -n "$namespace" "$item" -o yaml > "${ROOT}/${resource}/$item.yaml" &
    done < <(kubectl get "$resource" -n "$namespace" 2>&1  | tail -n +2)
done < <(kubectl api-resources --namespaced=true 2>/dev/null | grep -v "events" | tail -n +2 | awk '{print $1}')

wait
