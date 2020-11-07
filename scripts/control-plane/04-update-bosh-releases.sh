#!/bin/bash
set -eu

[ -z "${IAAS:-}" ] && echo '$IAAS must be set' && exit 2
[ -z "${PIVNET_TOKEN:-}" ] && echo '$PIVNET_TOKEN must be set' && exit 2

repo_root="$(cd "$(dirname "$0")/../.." && pwd)"

cleanup() {
  if [ -d "$temp_dir" ]; then
    rm -rf "$temp_dir"
    pivnet logout
  fi
}

trap cleanup EXIT

pivnet login --api-token="${PIVNET_TOKEN}"

# Need to hardcode the /tmp path here because Docker on Mac
# is unable to mount the default tmp directory without
# manual changing of permissions.
temp_dir="$(mktemp -d -p `pwd`)"

# get terraform output vars
terraform output -state="${repo_root}/state/terraform.tfstate" stable_config_opsmanager > "${temp_dir}/ops-manager-vars.json"

# Get ops manager ssh private key
om interpolate \
  --config "${temp_dir}/ops-manager-vars.json" \
  --path /ops_manager_ssh_private_key \
  > "${temp_dir}/opsman.pem"
chmod 600 "${temp_dir}/opsman.pem"

om interpolate \
  --config "${repo_root}/env/env.yml" \
  --vars-file "${temp_dir}/ops-manager-vars.json" \
  > "${temp_dir}/env.yml"

eval "$(om --env "${temp_dir}/env.yml" \
  bosh-env \
  --ssh-private-key "${temp_dir}/opsman.pem")"

p_concourse_latest_version="$(pivnet releases \
  --format=yaml \
  --product-slug=p-concourse \
  --limit=3 \
  | grep -E 'version:.*Platform Automation' \
  | sed 's/^.*version: //g')"

xenial_latest_version="$(pivnet releases \
  --format=yaml \
  --product-slug=stemcells-ubuntu-xenial \
  --limit=1 \
  | awk '/version: / {print $2}')"

pivnet download-product-files \
  --product-slug=p-concourse \
  --release-version="$p_concourse_latest_version" \
  --glob="*-release-*.tgz" \
  --download-dir="${temp_dir}"

# Need to use globbing here, as we do not know the version
# shellcheck disable=SC2086
for file in ${temp_dir}/*-release-*.tgz
do
  bosh upload-release ${file}
done

stemcell_glob="bosh-stemcell-*-${IAAS}-*.tgz"
if [[ "${IAAS}" == "aws" ]] || [[ "${IAAS}" == "google" ]]; then
  stemcell_glob="light-${stemcell_glob}"
fi

pivnet download-product-files \
  --product-slug=stemcells-ubuntu-xenial \
  --release-version="${xenial_latest_version//\"}" \
  --glob=${stemcell_glob} \
  --download-dir="${temp_dir}"

# Need to use globbing here, as we do not know the version
# shellcheck disable=SC2086
bosh upload-stemcell ${temp_dir}/*-stemcell-*-${IAAS}-*.tgz

bosh releases
bosh stemcells