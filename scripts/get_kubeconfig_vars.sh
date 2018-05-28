#!/bin/bash
source "${ROOT}/git-kubo-deployment/bin/lib/deploy_utils"
export_bosh_environment "${KUBO_ENVIRONMENT_DIR}"

cluster_name="${BOSH_NAME}/${DEPLOYMENT_NAME}"
host="$(bosh int "${KUBO_ENVIRONMENT_DIR}/director.yml" --path=/kubernetes_master_host)"
port="$(bosh int "${KUBO_ENVIRONMENT_DIR}/director.yml" --path=/kubernetes_master_port)"
api_url="https://${host}:${port}"
