#!/usr/bin/env bash

set -e

if [ -n "$1" ] && [ -z "$CLUSTER" ]; then
  export CLUSTER="$1"
  shift
fi

DOT=$(cd -P "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)
TPL="${DOT}/templates"
OUT_DIR="${OUT_DIR:-"${HOME}/kube/${CLUSTER}"}"
VM_HOST=$(hostname -s)
CLUSTER_DOMAIN="k8s.local"
LXD_DOMAIN="lxd.local"
if [ -z "$DEFAULT_DNS" ]; then
  DEFAULT_DNS="1.1.1.1"
fi

export DOT TPL OUT_DIR VM_HOST CLUSTER_DOMAIN LXD_DOMAIN DEFAULT_DNS

# shellcheck source=./lib/log.sh
source "$DOT/lib/utils.sh"

test -f "${OUT_DIR}/config" || test -f "/kube/config" || {
  echo "Could not find cluster config. Aborting!" >&2
  exit 1
}
load_env "${OUT_DIR}/config" "/kube/config" "${OUT_DIR}/env" "/kube/env"

command -v kubectl >/dev/null 2>&1 || {
  echo "Could not call kubectl. Check your PATH." >&2
  exit 1
}

# shellcheck source=/dev/null
source "$DOT/lib/cluster.sh"
# shellcheck source=/dev/null
if test -f "${OUT_DIR}/hooks.sh"; then
  source "${OUT_DIR}/hooks.sh"
fi
# shellcheck source=/dev/null
source "$DOT/lib/prepare.sh"
# shellcheck source=/dev/null
source "$DOT/lib/network.sh"
# shellcheck source=/dev/null
source "$DOT/lib/dns.sh"
# shellcheck source=/dev/null
source "$DOT/lib/orchestrate.sh"
# shellcheck source=/dev/null
source "$DOT/lib/provision.sh"
# shellcheck source=/dev/null
source "${DOT}/lib/vm.sh"
# shellcheck source=/dev/null
source "${DOT}/lib/addon.sh"
# shellcheck source=/dev/null
source "${DOT}/lib/auth.sh"

start() {
  dumpstack "$*"

  # run cluster-specific hook, accept errors
  set +e
  utils::function_exists hooks::pre_start && hooks::pre_start
  set -e

  dns::restore_resolvconf
  utils::wait_for_net

  prepare
  utils::function_exists "vm::prepare" && vm::prepare

  # master goes first
  orchestrate::master

  # reload dynamic environment after orchestration
  load_env "${OUT_DIR}/env"

  # we should get kubectl access after this
  network::cycle
  cluster::configure
  export KUBECONFIG="${HOME}/.kube/${CLUSTER}"

  # deploy system addons (including CoreDNS)
  utils::wait_for_master
  addon::sys

  # wait for DNS, then mangle resolv.conf and re-configure the lxc dnsmasq
  dns::wait_for_coredns
  dns::configure_lxc_network
  dns::configure_resolvconf

  # finally - boot up regular worker Joes
  orchestrate::workers
  network::cycle

  # run cluster-specific hook, accept errors
  set +e
  utils::function_exists hooks::post_start && hooks::post_start
  set -e
}

stop() {
  dumpstack "$*"

  # run cluster-specific hook, accept errors
  set +e
  utils::function_exists hooks::pre_stop && hooks::pre_stop
  set -e

  network::stop
  cluster::stop
  dns::restore_resolvconf

  # run cluster-specific hook, accept errors
  set +e
  utils::function_exists hooks::post_stop && hooks::post_stop
  set -e
}

clean() {
  stop

  # Clean prepare stage
  rm -rf "${OUT_DIR:?}/bin"
  rm -rf "${OUT_DIR:?}/.done"

  cluster::clean
  utils::function_exists "vm::clean" && vm::clean
}

"$@"
