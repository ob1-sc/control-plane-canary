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
terraform output -state="${repo_root}/state/terraform.tfstate" stable_config_opsmanager > "${temp_dir}/ops-manager-vars.yml"
terraform output -state="${repo_root}/state/terraform.tfstate" stable_config_concourse > "${temp_dir}/concourse-vars.yml"

# Get ops manager ssh private key
om interpolate \
  --config "${temp_dir}/ops-manager-vars.yml" \
  --path /ops_manager_ssh_private_key \
  > "${temp_dir}/opsman.pem"
chmod 600 "${temp_dir}/opsman.pem"

om interpolate \
  --config "${repo_root}/env/env.yml" \
  --vars-file "${temp_dir}/ops-manager-vars.yml" \
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

pivnet download-product-files \
  --product-slug=p-concourse \
  --release-version="$p_concourse_latest_version" \
  --glob="*-deployment-*.tgz" \
  --download-dir="${temp_dir}"

concourse_dir="${temp_dir}/concourse-bosh-deployment"
mkdir -p "${concourse_dir}"
tar -C "${concourse_dir}" -xzf $(ls ${temp_dir}/concourse-bosh-deployment-*.tgz)

pushd ${temp_dir}

  # deploy concourse
  bosh -n -d concourse deploy concourse-bosh-deployment/cluster/concourse.yml \
    -o concourse-bosh-deployment/cluster/operations/privileged-http.yml \
    -o concourse-bosh-deployment/cluster/operations/privileged-https.yml \
    -o concourse-bosh-deployment/cluster/operations/basic-auth.yml \
    -o concourse-bosh-deployment/cluster/operations/tls-vars.yml \
    -o concourse-bosh-deployment/cluster/operations/tls.yml \
    -o concourse-bosh-deployment/cluster/operations/uaa.yml \
    -o concourse-bosh-deployment/cluster/operations/scale.yml \
    -o concourse-bosh-deployment/cluster/operations/credhub-colocated.yml \
    -o concourse-bosh-deployment/cluster/operations/offline-releases.yml \
    -o concourse-bosh-deployment/cluster/operations/backup-atc-colocated-web.yml \
    -o concourse-bosh-deployment/cluster/operations/secure-internal-postgres.yml \
    -o concourse-bosh-deployment/cluster/operations/secure-internal-postgres-bbr.yml \
    -o concourse-bosh-deployment/cluster/operations/secure-internal-postgres-uaa.yml \
    -o concourse-bosh-deployment/cluster/operations/secure-internal-postgres-credhub.yml \
    -o "${repo_root}/config/ops-files/concourse-${IAAS}.yml" \
    -l <(om interpolate --config ${repo_root}/vars/${IAAS}/concourse.yml \
                  --vars-file ${temp_dir}/ops-manager-vars.yml \
                  --vars-file ${temp_dir}/concourse-vars.yml) \
    -l concourse-bosh-deployment/versions.yml

popd