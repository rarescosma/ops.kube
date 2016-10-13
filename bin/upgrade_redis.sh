#!/bin/bash

set -o nounset
set -o pipefail

DOCKER_PREFIX="kube-registry.kube-system.svc:5000/redis-slave"

VERSION=$1
kubectl set image deployment/redis-slave slave=${DOCKER_PREFIX}:$VERSION
