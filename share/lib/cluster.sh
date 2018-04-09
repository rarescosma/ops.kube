#!/usr/bin/env bash

cluster::stop() {
  dumpstack "$*"
  for mid in $(vm::discover "$CLUSTER" master); do
    vm::stop "${mid}" &
  done

  for wid in  $(vm::discover "$CLUSTER" worker); do
    vm::stop "${wid}" &
  done

  wait
}

cluster::configure() {
  dumpstack "$*"

  # shellcheck source=/dev/null
  source "${DOT}/${CLUSTER}-cluster.sh"
  utils::template "$TPL/kubeconfig_admin" > "$HOME/.kube/$CLUSTER"
}

cluster::configure_secure() {
  dumpstack "$*"

  # shellcheck source=/dev/null
  source "${DOT}/${CLUSTER}-cluster.sh"

  local kc='kubectl config'

  $kc set-cluster "${CLUSTER}" \
  --certificate-authority="${DOT}/etc/tls/${CLUSTER}/ca.pem" \
  --embed-certs=true \
  --server="https://${MASTER0_IP}:6443"

  $kc set-credentials "${CLUSTER}-root" --token "${SECRET_TOKEN}"

  $kc set-context "${CLUSTER}" \
  --cluster="${CLUSTER}" \
  --user="${CLUSTER}-root"

  $kc use-context "${CLUSTER}"
}

cluster::clean() {
  dumpstack "$*"
  vm::destroy "$(vm::discover "$CLUSTER" master)"
  vm::destroy "$(vm::discover "$CLUSTER" worker)"
  cp -f "${DOT}/cluster.sh.empty" "${DOT}/${CLUSTER}-cluster.sh"
}
