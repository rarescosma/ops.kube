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
  prepare::lxd
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

  [ -f "$auth_dir/kubernetes.pem" ] && return

  export KUBE_SERVICE_CLUSTER_IP="$(utils::service_ip "$SERVICE_CIDR").1"

  # CA
  cd "$auth_dir" || exit
  cfssl gencert -initca "${tpl_dir}/ca-csr.json" | cfssljson -bare ca

  # admin client cert + kubeconfig
  auth::make_cert admin admin
  auth::make_kubeconfig admin admin

  # master certs
  auth::make_cert kubernetes kubernetes
  auth::make_cert kube-controller-manager kube-controller-manager
  auth::make_cert kube-scheduler kube-scheduler

  # master kubeconfigs
  auth::make_kubeconfig kube-controller-manager
  auth::make_kubeconfig kube-scheduler

  # service account cert
  auth::make_cert service-account service-account

  cd - || exit
}

prepare::lxd() {
  dumpstack
  local lxd_unit

  if [ -x "$(command -v snap)" ]; then
    lxd_unit="snap.lxd.daemon"
  else
    lxd_unit="lxd"
  fi

  # restart lxd and wait for it
  sudo systemctl is-active --quiet ${lxd_unit} || {
    sudo systemctl restart ${lxd_unit}
    while true; do
      lxc list 1>/dev/null && break
      sleep 1
    done
  }
}
