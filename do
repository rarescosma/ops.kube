#!/usr/bin/env bash

set -e

if [ -n "$1" ] && [ -z "$CLUSTER" ]; then
  export CLUSTER="$1"
  shift
fi

DOT=$(cd -P "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)
TPL="${DOT}/templates"
OUT_DIR="${PREFIX:-${HOME}}/kube/${CLUSTER}"
VM_HOST=$(hostname -s)

export DOT TPL OUT_DIR VM_HOST

# shellcheck source=./lib/log.sh
source "$DOT/lib/utils.sh"

test -f "${OUT_DIR}/config" || test -f "/kube/config" || {
  echo "Could not find cluster config. Aborting!" >&2
  exit 1
}
load_env "${OUT_DIR}/config" "/kube/config" "${OUT_DIR}/env" "/kube/env"

# shellcheck source=/dev/null
source "$DOT/lib/cluster.sh"
# shellcheck source=/dev/null
if test -f "${DOT}/lib/host.${KUBE_HOST}.sh"; then
  source "${DOT}/lib/host.${KUBE_HOST}.sh"
fi
# shellcheck source=/dev/null
source "$DOT/lib/prepare.sh"
# shellcheck source=/dev/null
source "$DOT/lib/network.sh"
# shellcheck source=/dev/null
source "$DOT/lib/orchestrate.sh"
# shellcheck source=/dev/null
source "$DOT/lib/provision.sh"
# shellcheck source=/dev/null
source "${DOT}/lib/vm.sh"
# shellcheck source=/dev/null
source "${DOT}/lib/addon.sh"

start() {
  dumpstack "$*"
  utils::function_exists "host::prepare" && host::prepare

  prepare
  utils::function_exists "vm::prepare" && vm::prepare
  orchestrate::main

  network::start
  cluster::configure
  host::post
}

stop() {
  dumpstack "$*"
  utils::function_exists "host::stop" && host::stop

  network::stop
  cluster::stop
}

clean() {
  stop

  # Clean prepare stage
  rm -rf "${OUT_DIR:?}/bin/*"

  cluster::clean
  utils::function_exists "vm::clean" && vm::clean
}

"$@"
