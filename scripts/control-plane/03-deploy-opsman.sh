#!/bin/bash
set -eu

[ -z "${IAAS:-}" ] && echo '$IAAS must be set' && exit 2

repo_root="$(cd "$(dirname "$0")/../.." && pwd)"

cleanup() {
  if [ -d "$temp_dir" ]; then
    rm -rf "$temp_dir"
    pivnet logout
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

temp_dir="$(mktemp -d -p `pwd`)"

pivnet login --api-token="${PIVNET_TOKEN}"

pa_latest_version="$(pivnet releases \
  --format=yaml \
  --product-slug=platform-automation \
  --limit=1 \
  | awk '/version: / {print $2}')"

# Get latest Ops Manager image
opsman_latest_version="$(pivnet releases \
  --format=yaml \
  --product-slug=ops-manager \
  --limit=1 \
  | awk '/version: / {print $2}')"

pivnet download-product-files \
  --product-slug=ops-manager \
  --release-version="$opsman_latest_version" \
  --glob="ops-manager-${IAAS}-*.yml" \
  --download-dir="${temp_dir}/"

# Need to have the file path glob because the version can change
# shellcheck disable=SC2086
opsman_filename="$(basename ${temp_dir}/ops-manager-${IAAS}-*.yml)"

# get terraform output vars
terraform output -state="${repo_root}/state/terraform.tfstate" stable_config_opsmanager > "${temp_dir}/ops-manager-vars.json"

# Need to interpolate tf output into Ops Manager env file
docker_run om interpolate \
  --config /workdir/env/env.yml \
  --vars-file /tempdir/ops-manager-vars.json \
  > "${temp_dir}/env.yml"

# Create Ops Manager
docker_run p-automator create-vm \
  --config /workdir/config/opsman-${IAAS}.yml \
  --image-file "/tempdir/${opsman_filename}"  \
  --state-file /workdir/state/opsman_state.yml \
  --vars-file /tempdir/ops-manager-vars.json

# Configure Ops Manager auth
om_target="$(awk '/target: / {print $2}' "${temp_dir}/env.yml")"

# shellcheck disable=SC2091
until $(curl --output /dev/null -k --silent --head --fail "${om_target}/setup"); do
    printf '.'
    sleep 5
done

docker_run om \
  --env /tempdir/env.yml \
  configure-authentication \
  --config /workdir/config/auth.yml \
  --vars-file /tempdir/ops-manager-vars.json

# Configure BOSH Director
docker_run om \
  --env /tempdir/env.yml \
  configure-director \
  --config /workdir/config/director-${IAAS}.yml \
  --vars-file /tempdir/ops-manager-vars.json

# Apply Director Changes
docker_run om \
  --env /tempdir/env.yml \
  apply-changes \
  --reattach \
  --skip-deploy-products