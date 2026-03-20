#!/bin/bash
set -euo pipefail

: "${IMG_TAG:?IMG_TAG is required}"
: "${GH_TOKEN:?GH_TOKEN is required}"

TESTING_TARGETS="${TESTING_TARGETS:-kind,k3s}"
TESTING_REPO_OWNER="${TESTING_REPO_OWNER:-${GITHUB_REPOSITORY_OWNER:-}}"
MY_OPERATOR_IMAGE="${MY_OPERATOR_IMAGE:-apache/openserverless-operator}"

if test -z "$TESTING_REPO_OWNER"
then
    echo "TESTING_REPO_OWNER is required" >&2
    exit 1
fi

IFS=',' read -r -a targets <<< "$TESTING_TARGETS"
test_tags=()
for raw_target in "${targets[@]}"
do
    target="$(echo "$raw_target" | xargs)"
    if test -z "$target"
    then
        continue
    fi
    test_tags+=("${target}-${IMG_TAG}")
done

if test "${#test_tags[@]}" -eq 0
then
    echo "No testing tags requested." >&2
    exit 1
fi

echo "Operator image: ${MY_OPERATOR_IMAGE}:${IMG_TAG}"
echo "Dispatching testing tags: ${test_tags[*]}"

gh api "repos/${TESTING_REPO_OWNER}/openserverless-testing/dispatches" \
  -X POST \
  -f event_type=operator-release-testing \
  -f "client_payload[operator_tag]=${IMG_TAG}" \
  -f "client_payload[operator_image]=${MY_OPERATOR_IMAGE}" \
  -f "client_payload[targets]=${TESTING_TARGETS}"
