#!/bin/bash

clean::binaries() {
  rm -rf $DOT/bin/*
}

clean::tls() {
  rm -rf $DOT/etc/tls/*
}

clean::lxc_artefacts() {
  # LXC profile and base image
  lxc profile delete $LXC_PROFILE
  lxc image delete $LXC_IMG
}

clean::lxc_containers() {
  # All containers starting with master or worker
  lxc delete -f $(lxc list -c n master | grep master | cut -d" " -f2)
  lxc delete -f $(lxc list -c n worker | grep worker | cut -d" " -f2)
}
