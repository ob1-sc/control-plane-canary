#!/bin/bash

set -eu

repo_root="$(cd "$(dirname "$0")/../.." && pwd)"

cleanup() {
  if [ -d "$temp_dir" ]; then
    rm -rf "$temp_dir"
  fi
}

trap cleanup EXIT

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

# Delete BOSH deployments
bosh \
  --deployment concourse \
  --non-interactive \
  delete-deployment