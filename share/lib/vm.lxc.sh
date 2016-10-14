#!/bin/bash

vm::prepare() {
  vm::update_profile
  lxc image show $LXC_IMG 2>/dev/null || vm::create_base_image $LXC_IMG
}

vm::update_profile() {
  (lxc profile list | grep $LXC_PROFILE) >/dev/null
  if [ $? -gt 0 ]; then
    echo "Creating LXC profile ${LXC_PROFILE}"
    lxc profile create $LXC_PROFILE
  fi

  echo "Updating ${LXC_PROFILE}"
  utils::template $TPL/lxc_profile.yaml | lxc profile edit $LXC_PROFILE
}

vm::create_base_image() {
  local image=${1:-"$LXC_IMG"}

  echo "Creating LXC base image ${image}"
  local vm="kubetmp-$(utils::get_random_string)"

  lxc launch $LXC_IMG_FROM $vm --profile $LXC_PROFILE || lxc start $vm
  vm::exec $vm provision::base

  lxc stop $vm;
  lxc publish $vm --alias $image
  lxc delete $vm --force
}

vm::launch() {
  local vm="$1"
  (lxc launch $LXC_IMG $vm --profile $LXC_PROFILE || lxc start $vm) 2>/dev/null
}

vm::assert_vm() {
  [[ "lxc" == $(printenv container) ]] || \
  (echo "Error: not in an LXC container" && exit 1)
}

vm::exec() {
  local vm=$1; shift
  lxc exec $vm -- /kube/do $@
}

vm::discover_workers() {
  lxc list -c 4 worker | grep eth0 | cut -d" " -f2
}

vm::clean_artefacts() {
  # LXC profile and base image
  lxc profile delete $LXC_PROFILE
  lxc image delete $LXC_IMG
}

vm::delete_containers() {
  # All containers starting with master or worker
  lxc delete -f $(lxc list -c n master | grep master | cut -d" " -f2)
  lxc delete -f $(lxc list -c n worker | grep worker | cut -d" " -f2)
}
