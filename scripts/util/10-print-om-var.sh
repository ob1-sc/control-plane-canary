#!/bin/bash
set -eu

repo_root="$(cd "$(dirname "$0")/../.." && pwd)"

cleanup() {
  if [ -d "$temp_dir" ]; then
    rm -rf "$temp_dir"
  fi
}

trap cleanup EXIT

temp_dir="$(mktemp -d -p `pwd`)"

# get terraform output vars
terraform output -state="${repo_root}/state/terraform.tfstate" stable_config_opsmanager > "${temp_dir}/ops-manager-vars.json"

cat "${temp_dir}/ops-manager-vars.json" | jq -r .$([ -z $1 ] || echo $1)