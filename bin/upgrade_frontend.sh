#!/bin/bash

set -o nounset
set -o pipefail

DOCKER_PREFIX="localhost:5000/guestbook/frontend"

VERSION=$1
kubectl set image deployment/frontend php-redis=${DOCKER_PREFIX}:$VERSION
