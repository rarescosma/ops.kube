#!/usr/bin/env bash

auth::make_cert() {
  local csr name auth_dir
  role=$1
  name=$2

  auth_dir="${OUT_DIR}/auth"
  mkdir -p "$auth_dir"

  cd "$auth_dir" || exit
  export LXD_CIDR_PREFIX=$(network::lxd_cidr_prefix)
  utils::template "${TPL}/auth/${role}-csr.json" > "${auth_dir}/${name}-csr.json"

  cfssl gencert \
    -ca=ca.pem \
    -ca-key=ca-key.pem \
    -config="${TPL}/auth/ca-config.json" \
    -profile=kubernetes \
    "${auth_dir}/${name}-csr.json" | cfssljson -bare $name

  cd - || exit
}

auth::make_kubeconfig() {
  local unit auth_dir server user
  unit=$1
  user=${2:-"system:$unit"}
  server=${3:-"127.0.0.1"}

  auth_dir="${OUT_DIR}/auth"
  mkdir -p "$auth_dir"

  cd "$auth_dir" || exit

  $KUBECTL config set-cluster $CLUSTER \
    --certificate-authority=ca.pem \
    --embed-certs=true \
    --server=https://${server}:6443 \
    --kubeconfig=${unit}.kubeconfig

  $KUBECTL config set-credentials $user \
    --client-certificate=${unit}.pem \
    --client-key=${unit}-key.pem \
    --embed-certs=true \
    --kubeconfig=${unit}.kubeconfig

  $KUBECTL config set-context $CLUSTER \
    --cluster=$CLUSTER \
    --user=$user \
    --kubeconfig=${unit}.kubeconfig

  $KUBECTL config use-context $CLUSTER --kubeconfig=${unit}.kubeconfig

  cd - || exit
}


