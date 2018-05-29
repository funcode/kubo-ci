#!/bin/bash
bosh_name="$(bosh int "${KUBO_ENVIRONMENT_DIR}/director.yml" --path=/director_name)"
cluster_name="${bosh_name}/${DEPLOYMENT_NAME}"
host="$(bosh int "${KUBO_ENVIRONMENT_DIR}/director.yml" --path=/kubernetes_master_host)"
port="$(bosh int "${KUBO_ENVIRONMENT_DIR}/director.yml" --path=/kubernetes_master_port)"
api_url="https://${host}:${port}"
