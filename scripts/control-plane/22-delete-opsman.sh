#!/bin/bash
set -eu

[ -z "${IAAS:-}" ] && echo '$IAAS must be set' && exit 2
[ -z "${PIVNET_TOKEN:-}" ] && echo '$PIVNET_TOKEN must be set' && exit 2

repo_root="$(cd "$(dirname "$0")/../.." && pwd)"

cleanup() {
  if [ -d "$temp_dir" ]; then
    rm -rf "$temp_dir"
  fi
}

docker_run() {
  docker run \
    --volume="${repo_root}:/workdir" \
    --volume="${temp_dir}:/tempdir" \
    --workdir="/workdir" \
    "platform-automation-image:${pa_latest_version}" \
    "$@"
}

trap cleanup EXIT

pivnet login --api-token="${PIVNET_TOKEN}"

# Need to hardcode the /tmp path here because Docker on Mac
# is unable to mount the default tmp directory without
# manual changing of permissions.
temp_dir="$(mktemp -d -p `pwd`)"

# Update platform automation image
pa_latest_version="$(pivnet releases \
  --format=yaml \
  --product-slug=platform-automation \
  --limit=1 \
  | awk '/version: / {print $2}')"

# get terraform output vars
terraform output -state="${repo_root}/state/terraform.tfstate" stable_config_opsmanager > "${temp_dir}/ops-manager-vars.json"

# Need to interpolate tf output into Ops Manager env file
docker_run om interpolate \
  --config /workdir/env/env.yml \
  --vars-file /tempdir/ops-manager-vars.json \
  > "${temp_dir}/env.yml"

# Delete BOSH
docker_run om \
  --env /tempdir/env.yml \
  --request-timeout 30 \
  delete-installation \
  --force

# Create Ops Manager
docker_run p-automator delete-vm \
  --config /workdir/config/opsman-${IAAS}.yml \
  --state-file /workdir/state/opsman_state.yml \
  --vars-file /tempdir/ops-manager-vars.json