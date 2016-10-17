#!/bin/bash

vm::prepare() {
  # volume on /kube/share
  # base image for ubuntu
  echo "fully prepared..."
}

vm::launch() {
  local vm="$1"
  docker run -dit \
  --privileged \
  --name="${vm}" \
  --hostname="${vm}" \
  --cap-add=SYS_ADMIN \
  --volume=/sys/fs/cgroup:/sys/fs/cgroup:ro \
  --volume=/sys:/sys:ro \
  -v "${DOT}:/kube" \
    ${DOCKER_BASE_IMG} /sbin/init
}

vm::assert_vm() {
  (cat /proc/1/cgroup | grep docker) &>/dev/null \
  || (echo "Error: not in a Docker container" && exit 1)
}

vm::exec() {
  local vm=$1; shift
  docker exec $vm /kube/do $@
}

vm::discover_workers() {
  docker inspect $(docker ps --filter=name=worker -q -a) \
  | grep IPAddress | grep -v null \
  | cut -d: -f2 | sed 's/[^0-9.]*//g' \
  | sort -u
}

vm::clean_artefacts() {
  echo "fully cleaned..."
}

vm::delete_containers() {
  docker rm -f $(docker ps --filter=name=worker -q -a) &
  docker rm -f $(docker ps --filter=name=master -q -a) &
  wait
}
