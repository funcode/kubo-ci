#!/bin/bash

set -exu -o pipefail

ROOT="$( cd "$( dirname "${BASH_SOURCE[0]}" )/../.." && pwd )"

. "$(dirname "$0")/lib/environment.sh"

export BOSH_LOG_LEVEL=debug
export BOSH_LOG_PATH="${ROOT}/bosh.log"
export DEBUG=1

metadata_path="${KUBO_ENVIRONMENT_DIR}/director.yml"
if [[ -z ${LOCAL_DEV+x} ]] || [[ "$LOCAL_DEV" != "1" ]]; then
  cp "${ROOT}/gcs-bosh-creds/creds.yml" "${KUBO_ENVIRONMENT_DIR}/"
  cp "${ROOT}/kubo-lock/metadata" "$metadata_path"
  tarball_name=$(ls ${ROOT}/gcs-kubo-release-tarball/kubo-*.tgz | head -n1)

  # Copy guestbook if WITHOUT_ADDONS isn't set to true
  if [[ -z ${WITHOUT_ADDONS+x} ]] || [[ "$WITHOUT_ADDONS" != "1" ]]; then
    cp "${ROOT}/git-kubo-ci/specs/guestbook.yml" "${KUBO_ENVIRONMENT_DIR}/addons.yml"
  else
    # Delete the addons_spec_path from director.yml
    sed -i.bak '/^addons_spec_path:/d' ${metadata_path}
  fi

else
  tarball_name="$KUBO_RELEASE_TARBALL"
fi

if [[ -z ${WITH_PRIVILEGED_CONTAINERS+x} ]] || [[ "$WITH_PRIVILEGED_CONTAINERS" == "1" ]]; then
  echo "allow_privileged_containers: true" >> "${metadata_path}"
fi

cp "$tarball_name" "${ROOT}/kubo-release.tgz"

"$KUBO_DEPLOYMENT_DIR/bin/set_bosh_alias" "${KUBO_ENVIRONMENT_DIR}"

release_source="local"

DEPLOYMENT_OPS_FILE=${DEPLOYMENT_OPS_FILE:-""}
IFS=';' read -r -a OPS_FILES <<< "$DEPLOYMENT_OPS_FILE"
for ops_file in "${OPS_FILES[@]}"
do
  if [[ -f "${KUBO_CI_DIR}/manifests/ops-files/${ops_file}" ]]; then
    cat "${KUBO_CI_DIR}/manifests/ops-files/${ops_file}" >> "${KUBO_ENVIRONMENT_DIR}/${DEPLOYMENT_NAME}.yml"
  fi
done

set +x
export DEBUG=0
"$KUBO_DEPLOYMENT_DIR/bin/deploy_k8s" "${KUBO_ENVIRONMENT_DIR}" "${DEPLOYMENT_NAME}" "$release_source"
set -x
export DEBUG=1

"$KUBO_DEPLOYMENT_DIR/bin/set_kubeconfig" "${KUBO_ENVIRONMENT_DIR}" "${DEPLOYMENT_NAME}"
if [[ -z ${LOCAL_DEV+x} ]] || [[ "$LOCAL_DEV" != "1" ]]; then
  cp ~/.kube/config "${ROOT}/gcs-kubeconfig/config"
fi
