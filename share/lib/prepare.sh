#!/bin/bash

prepare::bin() {
  mkdir -p $DOT/.bincache $DOT/bin
  bin::sync_kube &
  bin::sync_etcd &
  bin::sync_docker &
  wait

  echo "Creating symlinks"
  pushd $DOT/bin
  ln -sf ../.bincache/kube_${KUBE_VERSION}/* $DOT/bin/
  ln -sf ../.bincache/etcd_${ETCD_VERSION}/* $DOT/bin/
  ln -sf ../.bincache/docker_${DOCKER_VERSION}/* $DOT/bin/
  popd

  chmod -R +x $DOT/.bincache
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

prepare::lxc() {
  lxc::update_profile
  lxc image show $LXC_IMG 2>/dev/null || lxc::create_base_image $LXC_IMG
}
