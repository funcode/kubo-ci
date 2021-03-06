#!/bin/bash
set -euox pipefail
ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)

source "${ROOT}/git-kubo-ci/scripts/lib/utils.sh"
setup_env "${KUBO_ENVIRONMENT_DIR}"

go get github.com/cfcr/istio || true # go get returns error "no Go files", which is expected
cd $GOPATH/src/gtihub.com/cfcr/istio
git checkout 0.8.0
./bin/init_helm.sh
make e2e_simple TAG='0.8.0' E2E_ARGS='--installer=helm'
