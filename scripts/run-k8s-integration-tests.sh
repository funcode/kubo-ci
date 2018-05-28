#!/usr/bin/env bash

set -eu -o pipefail

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)

DEPLOYMENT_NAME="${DEPLOYMENT_NAME:="ci-service"}"
KUBO_ENVIRONMENT_DIR="${ROOT}/environment"

export GOPATH="${ROOT}/git-kubo-ci"

setup_env() {
  mkdir -p "${KUBO_ENVIRONMENT_DIR}"
  cp "${ROOT}/gcs-bosh-creds/creds.yml" "${KUBO_ENVIRONMENT_DIR}/"
  cp "${ROOT}/kubo-lock/metadata" "${KUBO_ENVIRONMENT_DIR}/director.yml"

  "${ROOT}/git-kubo-deployment/bin/set_bosh_alias" "${KUBO_ENVIRONMENT_DIR}"
  cluster_name="${BOSH_NAME}/${DEPLOYMENT_NAME}"
  host="$(bosh int "${KUBO_ENVIRONMENT_DIR}/director.yml" --path=/kubernetes_master_host)"
  port="$(bosh int "${KUBO_ENVIRONMENT_DIR}/director.yml" --path=/kubernetes_master_port)"
  api_url="https://${host}:${port}"
  "${ROOT}/git-kubo-deployment/bin/credhub_login" "${KUBO_ENVIRONMENT_DIR}"
  "${ROOT}/git-kubo-deployment/bin/set_kubeconfig" "${cluster_name}" "${api_url}"
}

main() {
  setup_env

  local tmpfile="$(mktemp)" && echo "CONFIG=${tmpfile}"
  "${ROOT}/git-kubo-ci/scripts/generate-test-config.sh" ${KUBO_ENVIRONMENT_DIR} ${DEPLOYMENT_NAME} > "${tmpfile}"

  CONFIG="${tmpfile}" ginkgo -r -progress -v "${ROOT}/git-kubo-ci/src/tests/integration-tests/"
}

main
