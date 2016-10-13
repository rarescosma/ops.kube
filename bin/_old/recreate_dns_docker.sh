#!/bin/bash

KUBE2SKY_IMAGE="gcr.io/google_containers/kube2sky:1.11"
SKYDNS_IMAGE="gcr.io/google_containers/skydns:2015-03-11-001"
LXC_NODE="kube-node-01"

docker rm -f $(docker ps -qa --filter "ancestor=${KUBE2SKY_IMAGE}")
docker rm -f $(docker ps -qa --filter "ancestor=${SKYDNS_IMAGE}")

docker run -d --name kube2sky --net=host --restart=always      \
              $KUBE2SKY_IMAGE                                  \
              -v=10 -logtostderr=true -domain=kubernetes.local \
              -etcd-server="http://10.0.40.96:2379"            \
              -kube_master_url="http://10.0.40.96:8080"

docker run -d --name skydns --net=host --restart=always       \
              -e ETCD_MACHINES="http://10.0.40.96:2379"       \
              -e SKYDNS_DOMAIN="kubernetes.local"             \
              -e SKYDNS_ADDR="0.0.0.0:53"                     \
              -e SKYDNS_NAMESERVERS="8.8.8.8:53,8.8.4.4:53"   \
              $SKYDNS_IMAGE
