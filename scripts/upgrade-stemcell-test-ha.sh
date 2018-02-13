#!/bin/bash

set -eo pipefail

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

. "$DIR/lib/environment.sh"
. "$DIR/lib/upgrade-tests.sh"

HA_MIN_SERVICE_AVAILABILITY="${HA_MIN_SERVICE_AVAILABILITY:-1}"

if ([ -z ${LOCAL_DEV+x} ] || [ "$LOCAL_DEV" != "1" ]) || [ -z "$BOSH_STEMCELL_VERSION" ]; then
  BOSH_STEMCELL_VERSION=$(cat ${PWD}/new-bosh-stemcell/version)
fi

update_stemcell() {
  local manifest_path="${KUBO_DEPLOYMENT_DIR}/manifests/cfcr.yml"
  local existing_version

  existing_version="$(bosh int "$manifest_path" --path=/stemcells/0/version)"

  echo "Updating $manifest_path's stemcell version from '$existing_version' to '$BOSH_STEMCELL_VERSION'"
  manifest=$(bosh int "$manifest_path" -o "$DIR/../manifests/ops-files/stemcell-upgrade.yml" -v "stemcell-version=$BOSH_STEMCELL_VERSION")
  echo "$manifest" > $manifest_path

  echo "Updating Stemcell..."
  export DEPLOYMENT_NAME=ci-service
  ${DIR}/deploy-k8s-instance.sh
}

set_kubeconfig
upload_new_releases
run_upgrade_test update_stemcell "$HA_MIN_SERVICE_AVAILABILITY"
