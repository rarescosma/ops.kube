#!/usr/bin/env bash

vm::prepare() {
  vm::update_profile
  lxc image show $LXD_BASE_IMG 2>/dev/null || vm::create_base_image $LXD_BASE_IMG
}

vm::update_profile() {
  (lxc profile list | grep $LXD_PROFILE) >/dev/null
  if [ $? -gt 0 ]; then
    echo "Creating LXC profile ${LXD_PROFILE}"
    lxc profile create $LXD_PROFILE
  fi

  echo "Updating ${LXD_PROFILE}"
  utils::template "${TPL}/lxd_profile.yaml" | lxc profile edit $LXD_PROFILE
}

vm::create_base_image() {
  local image=${1:-"$LXD_BASE_IMG"}

  echo "Creating LXC base image ${image}"
  local vm="kubetmp-$(utils::get_random_string)"

  lxc launch $LXD_IMG_FROM $vm --profile $LXD_PROFILE || lxc start $vm
  vm::exec $vm provision::base

  lxc stop $vm;
  lxc publish $vm --alias $image
  lxc delete $vm --force
}

vm::launch() {
  local vm="$1"
  (lxc launch $LXD_BASE_IMG $vm --profile $LXD_PROFILE || lxc start $vm)
}

vm::discover() {
  local tag="$1"
  local what=${2:-"ids"}
  case $what in
  "ips")
    lxc list -c 4 ${tag} | grep ${VM_IFACE} | cut -d" " -f2
    ;;
  *)
    lxc list -c n ${tag} | grep ${tag} | cut -d" " -f2
    ;;
  esac
}

vm::exec() {
  local vm=$1; shift
  lxc exec $vm -- /kube/do $@
}

vm::destroy() {
  lxc delete -f "$@"
}

vm::assert_vm() {
  [[ "lxc" == $(printenv container) ]] || \
  (echo "Error: not in an LXC container" && exit 1)
}

vm::clean() {
  # Cleanup profile and base image
  lxc profile delete $LXD_PROFILE
  lxc image delete $LXD_BASE_IMG
}
