#!/usr/bin/env bash

vm::create() {
  dumpstack "$*"
  local vm="$1"
  (
    lxc launch "$LXD_BASE_IMG" "$vm" --profile "$LXD_PROFILE" ||
    lxc start "$vm" ||
    true
  )
}

vm::destroy() {
  dumpstack "$*"
  if [ -n "$*" ]; then
    lxc delete -f $@ || true
  fi
}

vm::stop() {
  dumpstack "$*"
  lxc stop "$@" --force || true
}

vm::prepare() {
  dumpstack "$*"
  vm::update_profile
  lxc image show "$LXD_BASE_IMG" 2>/dev/null || vm::create_base_image "$LXD_BASE_IMG"
}

vm::update_profile() {
  dumpstack "$*"
  if ! (lxc profile list | grep "$LXD_PROFILE") >/dev/null; then
    echo "Creating LXC profile ${LXD_PROFILE}"
    lxc profile create "$LXD_PROFILE"
  fi

  echo "Updating ${LXD_PROFILE}"
  utils::template "${TPL}/lxd_profile.yaml" | lxc profile edit "$LXD_PROFILE"
}

vm::create_base_image() {
  dumpstack "$*"
  local image=${1:-"$LXD_BASE_IMG"}

  echo "Creating LXC base image ${image}"
  local vm
  vm="kubetmp-$(utils::get_random_string)"

  lxc launch "$LXD_IMG_FROM" "$vm" --profile "$LXD_PROFILE" || lxc start "$vm" || true
  vm::exec "$vm" provision::base

  lxc stop "$vm";
  lxc publish "$vm" --alias "$image"
  lxc delete "$vm" --force
}

vm::discover() {
  dumpstack "$*"
  local tag what nodes
  tag="${1}[0-9]+-${CLUSTER}"
  what=${2:-"ids"}

  nodes=$(lxc list -c n | grep -E -- "${tag}" | cut -d" " -f2)

  case $what in
  "ips")
    echo "$nodes" | \
      xargs -I{} lxc list -c 4 -- {} | \
      grep -- "${VM_IFACE}" | cut -d" " -f2
    ;;
  *)
    echo "$nodes"
    ;;
  esac
}

vm::exec() {
  dumpstack "$*"
  local vm=$1; shift
  lxc exec "$vm" --env OUT_DIR=/kube -- /ops.kube/do "${CLUSTER}" "$@"
}

vm::assert_vm() {
  [[ "lxc" == $(printenv container) ]] || \
  (echo "Error: not in an LXC container" >&2 && exit 1)
}

vm::clean() {
  dumpstack "$*"
  lxc profile delete "$LXD_PROFILE" || true
}
