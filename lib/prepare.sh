#!/usr/bin/env bash

CACHE_DIR="${KUBE_PV}/kube/cache"
declare -a _TARBALLS=(
  "https://github.com/coreos/etcd/releases/download/v${V_ETCD}/etcd-v${V_ETCD}-linux-amd64.tar.gz"
  "https://github.com/containernetworking/plugins/releases/download/v${V_CNI}/cni-plugins-linux-amd64-v${V_CNI}.tgz"
  "https://github.com/containerd/containerd/releases/download/v${V_CONTAINERD}/containerd-${V_CONTAINERD}-linux-amd64.tar.gz"
)

declare -a _BINS=(
  "https://github.com/opencontainers/runc/releases/download/v${V_RUNC}/runc.amd64"
  "https://storage.googleapis.com/kubernetes-release/release/v${V_KUBE}/bin/linux/amd64/kube-apiserver"
  "https://storage.googleapis.com/kubernetes-release/release/v${V_KUBE}/bin/linux/amd64/kube-controller-manager"
  "https://storage.googleapis.com/kubernetes-release/release/v${V_KUBE}/bin/linux/amd64/kube-proxy"
  "https://storage.googleapis.com/kubernetes-release/release/v${V_KUBE}/bin/linux/amd64/kube-scheduler"
  "https://storage.googleapis.com/kubernetes-release/release/v${V_KUBE}/bin/linux/amd64/kubectl"
  "https://storage.googleapis.com/kubernetes-release/release/v${V_KUBE}/bin/linux/amd64/kubelet"

)

prepare() {
  dumpstack "$*"
  prepare::bin
  prepare::tls
}

prepare::bin() {
  dumpstack "$*"
  local bin_dir done_dir done_file
  bin_dir="${OUT_DIR}/bin"
  done_dir="${OUT_DIR}/.done"
  mkdir -p "${bin_dir}" "${done_dir}"

  for bin in "${_BINS[@]}"; do
    target="${bin_dir}/$(basename ${bin})"
    [ -x "$target" ] || utils::download "${bin}" "${target}"
  done

  for tarball in "${_TARBALLS[@]}"; do
    done_file="${done_dir}/$(basename ${tarball})"
    [ -f "${done_file}" ] || {
      utils::pluck_binaries "${tarball}" "${bin_dir}"
      touch "${done_file}"
    }
  done
  chmod -R +x "${bin_dir}"
}

prepare::tls() {
  dumpstack "$*"
  local auth_dir tpl_dir
  auth_dir="${OUT_DIR}/auth"
  tpl_dir="${TPL}/auth"
  mkdir -p "$auth_dir"

  [ -f "$auth_dir/tls-kubernetes.pem" ] && return

  export KUBE_SERVICE_CLUSTER_IP="$(utils::service_ip "$SERVICE_CIDR").1"

  cd "$auth_dir" || exit
  cfssl gencert -initca "${tpl_dir}/tls-ca-csr.json" | cfssljson -bare tls-ca

  utils::template "${tpl_dir}/tls-kube-csr.json" > "${auth_dir}/tls-kube-csr.json"

  cfssl gencert \
    -ca=tls-ca.pem \
    -ca-key=tls-ca-key.pem \
    -config="${TPL}/auth/tls-ca-config.json" \
    -profile=kubernetes \
    "${auth_dir}/tls-kube-csr.json" | cfssljson -bare tls-kubernetes

  cd - || exit
}
