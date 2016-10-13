#!/bin/bash

lxc::exec() {
  local vm=$1; shift
  lxc exec $vm -- /kube/do $@
}

lxc::update_profile() {
  (lxc profile list | grep $LXC_PROFILE) >/dev/null
  if [ $? -gt 0 ]; then
    echo "Creating LXC profile ${LXC_PROFILE}"
    lxc profile create $LXC_PROFILE
  fi

  echo "Updating ${LXC_PROFILE}"
  utils::template $TPL/lxc_profile.yaml | lxc profile edit $LXC_PROFILE
}

lxc::create_base_image() {
  local image=${1:-"$LXC_IMG"}

  echo "Creating LXC base image ${image}"
  local vm="kubetmp-$(utils::get_random_string)"

  lxc launch $LXC_IMG_FROM $vm --profile $LXC_PROFILE || lxc start $vm
  lxc::exec $vm provision::base

  lxc stop $vm;
  lxc publish $vm --alias $image
  lxc delete $vm --force
}
