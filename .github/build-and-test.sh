#!/bin/bash
set -euo pipefail

: "${IMG_TAG:?IMG_TAG is required}"
: "${MY_OPERATOR_IMAGE:=apache/openserverless-operator}"

echo "Operator image repository: ${MY_OPERATOR_IMAGE}"
echo "Operator image tag: ${IMG_TAG}"
echo "Operator image reference: ${MY_OPERATOR_IMAGE}:${IMG_TAG}"

task setup
task build-and-load TAG="${IMG_TAG}"
task kind:ingress
task utest
task itest
