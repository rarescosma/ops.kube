#!/usr/bin/env bash

addon() {
  local addon
  addon="${1}"
  export KUBE_DNS_IP="$(utils::service_ip "$KUBE_SERVICE_CLUSTER_IP_RANGE")00"
  export KUBE_DNS_DOMAIN="kubernetes.local"

  utils::template "$TPL/addons/${addon}.yaml.tpl" \
  | tee "$TPL/addons/${addon}.yaml" \
  | kubectl apply -f -
}

addon::federation() {
  addon "federation"
  helm init --service-account="tiller" --tiller-namespace="kube-system" --upgrade || true

  helm del --purge etcd-operator

  helm ls --all etcd-operator | grep DEPLOYED || {
    helm install --namespace federation-support --name etcd-operator stable/etcd-operator
    helm upgrade --namespace federation-support --set cluster.enabled=true etcd-operator stable/etcd-operator
  }

  helm del --purge coredns

  helm ls --all coredns | grep DEPLOYED || {
    helm install --namespace federation-support --name coredns -f "${TPL}/addons/FederationCore.yaml" stable/coredns
  }
}
