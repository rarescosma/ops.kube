#!/usr/bin/env bash

CACHE_DIR="${KUBE_PV}/cache"

prepare() {
  prepare::bin
  prepare::tls
}

prepare::bin::sync_kube() {
  echo "Checking Kube bins v.${KUBE_VERSION}"
  local target="${CACHE_DIR}/kube_${KUBE_VERSION}" && mkdir -p $target

  if [ ! -x "${target}/kubectl" ]; then
    local tmp=$(mktemp -d)
    local release_dir="${tmp}/kubernetes/server/kubernetes/server/bin"
    local bin

    utils::download $KUBE_TGZ "${tmp}/archive.tgz"
    tar -C $tmp -xf "${tmp}/archive.tgz"

    # 1.5.4 compatibility - need an extra step to pull kube binaries
    pushd "${tmp}/kubernetes/cluster"
    KUBERNETES_SKIP_CONFIRM=1 ./get-kube-binaries.sh
    popd

    pushd "${tmp}/kubernetes/server"
    tar xzf kubernetes-server-linux-amd64.tar.gz
    popd

    for bin in "${KUBE_BINS[@]}"; do
      target="${CACHE_DIR}/kube_${KUBE_VERSION}/${bin}"
      [ -x $target ] || mv "${release_dir}/${bin}" $target
    done
  fi
}

prepare::bin::sync_etcd() {
  echo "Checking Etcd bins v.${ETCD_VERSION}"
  local target="${CACHE_DIR}/etcd_${ETCD_VERSION}" && mkdir -p $target
  [ -x "${target}/etcdctl" ] || utils::pull_tgz $ETCD_TGZ $target etcd
}

prepare::bin::sync_docker() {
  echo "Checking Docker bins v.${DOCKER_VERSION}"
  local target="${CACHE_DIR}/docker_${DOCKER_VERSION}" && mkdir -p $target
  [ -x "${target}/docker" ] || utils::pull_tgz $DOCKER_TGZ $target docker
}

prepare::bin() {
  mkdir -p $DOT/.bincache $DOT/bin
  prepare::bin::sync_kube &
  prepare::bin::sync_etcd &
  if [ -z ${USE_SYSTEM_DOCKER+x} ]; then
    prepare::bin::sync_docker &
  fi
  wait

  echo "Creating symlinks"
  pushd ${KUBE_PV}/bin
  ln -sf ../cache/kube_${KUBE_VERSION}/* .
  ln -sf ../cache/etcd_${ETCD_VERSION}/* .
  if [ -z ${USE_SYSTEM_DOCKER+x} ]; then
    ln -sf ../cache/docker_${DOCKER_VERSION}/* .
  fi
  popd

  chmod -R +x ${CACHE_DIR}
}

prepare::tls() {
  mkdir -p $DOT/etc/tls
  [ -f $DOT/etc/tls/kubernetes.pem ] && return

  pushd $DOT/etc/tls
  cfssl gencert -initca $TPL/tls_ca-csr.json | cfssljson -bare ca

  cfssl gencert \
    -ca=ca.pem \
    -ca-key=ca-key.pem \
    -config=$TPL/tls_ca-config.json \
    -profile=kubernetes \
    $TPL/tls_kube-csr.json | cfssljson -bare kubernetes
  popd
}
