#!/usr/bin/env bash

[ -z "$DEBUG" ] || set -x

set -eu
set -o pipefail

BASE_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")"/.. && pwd)

verify_args() {
  set +e # Cant be set since read returns a non-zero when it reaches EOF
  read -r -d '' usage <<-EOF
	Usage: $(basename "$0") [-h] environment deployment-name release-tarball results-dir conformance-test-spec-uri

	Help Options:
		-h  show this help text
	EOF
  set -e

  while getopts ':h' option; do
    case "$option" in
      h) echo "$usage"
         exit 0
         ;;
     \?) printf "Illegal option: -%s\n" "$OPTARG" >&2
         echo "$usage" >&2
         exit 64
         ;;
    esac
  done
  shift $((OPTIND - 1))
  if [[ $# -lt 4 ]]; then
    echo "$usage" >&2
    exit 64
  fi
}

run_tests() {
  local environment="$1"
  local deployment="$2"
  local results_dir="$3"
  local spec_uri="$4"

  local iaas=$(bosh int "$environment/director.yml" --path='/iaas')

  if [ ! -d "$results_dir" ]; then
    echo "Error: $results_dir does not exist" >&2
    exit 1
  fi

  local release_version=$(cat kubo-version/version)

  local tmpfile=$(mktemp)
  $BASE_DIR/scripts/generate-test-config.sh $environment $deployment > $tmpfile

  export CONFIG=${tmpfile}
  export CONFORMANCE_RESULTS_DIR="${results_dir}"
  export CONFORMANCE_RELEASE_VERSION="${release_version}"
  export CONFORMANCE_IAAS="${iaas}"
  export CONFORMANCE_SPEC_URI="${spec_uri}"

  ginkgo -progress -v "$BASE_DIR/src/tests/conformance"

  return 0
}

main() {
  verify_args "$@"
  run_tests "$@"
}

main "$@"
