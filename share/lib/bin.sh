#!/bin/bash

bin::sync_kube() {
  echo "Checking Kube bins v.${KUBE_VERSION}"
  local target="${DOT}/.bincache/kube_${KUBE_VERSION}" && mkdir -p $target

  if [ ! -x "${target}/kubectl" ]; then
    local tmp=$(mktemp -d)
    local release_dir="${tmp}/kubernetes/server/kubernetes/server/bin"
    local bin

    utils::download $KUBE_TGZ "${tmp}/archive.tgz"
    tar -C $tmp -xf "${tmp}/archive.tgz"
    pushd "${tmp}/kubernetes/server"
    tar xzf kubernetes-server-linux-amd64.tar.gz
    popd

    for bin in "${KUBE_BINS[@]}"; do
      target="${DOT}/.bincache/kube_${KUBE_VERSION}/${bin}"
      [ -x $target ] || mv "${release_dir}/${bin}" $target
    done
  fi
}

bin::sync_etcd() {
  echo "Checking Etcd bins v.${ETCD_VERSION}"
  local target="${DOT}/.bincache/etcd_${ETCD_VERSION}" && mkdir -p $target
  [ -x "${target}/etcdctl" ] || utils::pull_tgz $ETCD_TGZ $target etcd
}

bin::sync_docker() {
  echo "Checking Docker bins v.${DOCKER_VERSION}"
  local target="${DOT}/.bincache/docker_${DOCKER_VERSION}" && mkdir -p $target
  [ -x "${target}/docker" ] || utils::pull_tgz $DOCKER_TGZ $target docker
}
