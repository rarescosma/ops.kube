#!/usr/bin/env bash

CACHE_DIR="${KUBE_PV}/kube/cache"

prepare() {
  dumpstack "$*"
  prepare::bin
  prepare::tls
}

prepare::bin::sync_kube() {
  dumpstack "$*"
  echo "Checking Kube bins v.${KUBE_VERSION}"
  local target="${CACHE_DIR}/kube_${KUBE_VERSION}" && mkdir -p "$target"

  if [ ! -x "${target}/kubectl" ]; then
    local tmp
    tmp="$KUBE_PV/tmp"
    mkdir -p "$tmp"
    local release_dir="${tmp}/kubernetes/server/kubernetes/server/bin"
    local bin

    utils::download "$KUBE_TGZ" "${tmp}/archive.tgz"
    tar -C "$tmp" -xf "${tmp}/archive.tgz"

    # 1.5.4 compatibility - need an extra step to pull kube binaries
    cd "${tmp}/kubernetes/cluster" || exit
    KUBERNETES_SKIP_CONFIRM=1 ./get-kube-binaries.sh
    cd - || exit

    cd "${tmp}/kubernetes/server" || exit
    tar xzf kubernetes-server-linux-amd64.tar.gz
    cd - || exit

    for bin in "${KUBE_BINS[@]}"; do
      target="${CACHE_DIR}/kube_${KUBE_VERSION}/${bin}"
      [ -x "$target" ] || mv "${release_dir}/${bin}" "$target"
    done
  fi
}

prepare::bin::sync_etcd() {
  dumpstack "$*"
  echo "Checking Etcd bins v.${ETCD_VERSION}"
  local target="${CACHE_DIR}/etcd_${ETCD_VERSION}" && mkdir -p "$target"
  [ -x "${target}/etcdctl" ] || utils::pull_tgz "$ETCD_TGZ" "$target" etcd
}

prepare::bin::sync_docker() {
  dumpstack "$*"
  echo "Checking Docker bins v.${DOCKER_VERSION}"
  local target="${CACHE_DIR}/docker_${DOCKER_VERSION}" && mkdir -p "$target"
  [ -x "${target}/docker" ] || utils::pull_tgz "$DOCKER_TGZ" "$target" docker
}

prepare::bin() {
  dumpstack "$*"
  mkdir -p "${CACHE_DIR}"
  mkdir -p "$DOT/.bincache" "$DOT/bin"
  mkdir -p "${KUBE_PV}/kube/bin"

  prepare::bin::sync_kube &
  prepare::bin::sync_etcd &
  if [ -z "${USE_SYSTEM_DOCKER+x}" ]; then
    prepare::bin::sync_docker &
  fi
  wait

  echo "Creating symlinks"
  cd "${KUBE_PV}/kube/bin" || exit
  ln -sf "../cache/kube_${KUBE_VERSION}/"* .
  ln -sf "../cache/etcd_${ETCD_VERSION}/"* .
  if [ -z "${USE_SYSTEM_DOCKER+x}" ]; then
    ln -sf "../cache/docker_${DOCKER_VERSION}/"* .
  fi
  cd - || exit

  chmod -R +x "${CACHE_DIR}"
}

prepare::tls() {
  dumpstack "$*"
  local tls_dir
  tls_dir="$DOT/etc/tls/$CLUSTER"
  mkdir -p "$tls_dir"

  [ -f "$tls_dir/kubernetes.pem" ] && return

  cd "$tls_dir" || exit
  cfssl gencert -initca "$TPL/tls_ca-csr.json" | cfssljson -bare ca


  envsubst <"${TPL}/tls_kube-csr.json" >"${tls_dir}/tls_kube-csr.json"

  cfssl gencert \
    -ca=ca.pem \
    -ca-key=ca-key.pem \
    -config="$TPL/tls_ca-config.json" \
    -profile=kubernetes \
    "${tls_dir}/tls_kube-csr.json" | cfssljson -bare kubernetes

  cd - || exit
}
