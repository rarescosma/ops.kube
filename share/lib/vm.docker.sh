#!/usr/bin/env bash

vm::prepare() {
  vm::run_dns "${DOCKER_BRIDGE}"
}

vm::run_dns() {
  local interface=${1:-"$DOCKER_BRIDGE"}
  local ip
  ip=$(utils::get_ip "${interface}")
  docker run -d \
  --restart=always \
  --name="dnsdock" \
  --hostname="dnsdock" \
  -v /var/run/docker.sock:/var/run/docker.sock \
  -p "$ip:53:53/udp" \
  "${DOCKER_DNS_IMG}" \
  -domainless="true" \
  -nameserver="8.8.8.8:53,8.8.4.4:53"
}

vm::launch() {
  local vm="$1"; shift

  docker run -d \
  --privileged \
  --name="${vm}" \
  --hostname="${vm}" \
  --cap-add=SYS_ADMIN \
  --volume=/sys/fs/cgroup:/sys/fs/cgroup:ro \
  -v "${DOT}:/kube" \
  -v "${KUBE_PV}/kube:/pv/kube" \
  "${DOCKER_BASE_IMG}" /sbin/init || docker start "${vm}"
}

vm::discover() {
  local tag="$1"
  local what=${2:-"ids"}
  case $what in
  "ips")
    docker inspect --format '{{ .NetworkSettings.IPAddress }}' \
    "$(docker ps "--filter=name=${tag}" -q -a)"
    ;;
  *)
    docker ps "--filter=name=${tag}" -q -a
    ;;
  esac
}

vm::exec() {
  local vm=$1; shift
  docker exec "$vm" /kube/do "$@"
}

vm::destroy() {
  docker rm -f "$@"
}

vm::assert_vm() {
  grep docker </proc/1/cgroup &>/dev/null \
  || (echo "Error: not in a Docker container" && exit 1)
}

vm::clean() {
  # todo - cleanup dns container
  echo "Cleaning docker vm engine..."
  docker rm -f dnsdock
}
