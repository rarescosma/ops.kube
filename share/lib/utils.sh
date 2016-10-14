#!/bin/bash

# Shhhhhh...
pushd() {
  command pushd "$@" > /dev/null
}
popd() {
  command popd "$@" > /dev/null
}

utils::download() {
  local url=$1
  local dest=$2

  if [ -x "$(command -v axel)" ]; then
    axel -n 4 -o $dest $url
  else
    curl -sL $url -o $dest
  fi
}

utils::pull_tgz() {
  local tmp=$(mktemp -d)
  local url=$1
  local target=$2
  local glob_prefix=$3

  utils::download $url "${tmp}/archive.tgz"
  tar --strip-components=1 -C $tmp -xf $tmp/archive.tgz
  mv $tmp/${glob_prefix}* $target/
  rm -rf $tmp
}

utils::template() {
  eval "echo \"$(cat $1)\""
}

utils::get_random_string() {
  < /dev/urandom tr -dc A-Za-z0-9 | head -c${1:-8}
}

utils::get_ip() {
  ip addr show dev $NODE_IFACE | \
    grep -v inet6 | grep inet | \
    sed 's/^ *//;s/ *$//' | \
    cut -d" " -f2 | cut -d"/" -f1
}

utils::wait_ip() {
  local ip
  while [ 1 ]; do
    ip=$(utils::get_ip)
    if [[ "${ip}" != "" ]]; then
      echo $ip && break
    fi
    sleep 1
  done
}

utils::export_vm() {
  vm::assert_vm

  export VM_HOSTNAME=$(hostname)
  export VM_IP=$(utils::wait_ip)
}

utils::to_upper() {
  echo $@ | tr '[:lower:]' '[:upper:]'
}

utils::replace_line_by_prefix() {
  local fname=$1
  local prefix=$2
  local content=$3

  local tmp=$(mktemp -d)
  cat $fname | grep -v $prefix > $tmp/grepped
  echo "${prefix}${content}" | tee -a $tmp/grepped
  mv $tmp/grepped $fname
  rm -rf $tmp
}

utils::docker_subnet() {
  local worker_ip=$1
  echo "172.$(echo $worker_ip | cut -d. -f4).0.0/16"
}
