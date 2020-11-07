#!/bin/bash
[ -z "$REPO_LOCATION" ] && echo '$REPO_LOCATION must be set' && exit 2
repo_root=${REPO_LOCATION}

source ${repo_root}/scripts/util/11-bosh-credhub-proxy.sh

# get terraform output vars
terraform_outputs=$(terraform output -state="${repo_root}/state/terraform.tfstate" stable_config_concourse)

credhub_server=https://$(echo $terraform_outputs | jq -r '.concourse_url'):8844
credhub_client=credhub_admin
credhub_secret="$(credhub get -q -n /p-bosh/concourse/credhub_admin_secret)"
credhub_ca_cert="$(credhub get -n /p-bosh/concourse/atc_tls -k ca)"

echo $credhub_server

export unset CREDHUB_PROXY
export unset BOSH_ALL_PROXY
export CREDHUB_SERVER=$credhub_server
export CREDHUB_CLIENT=$credhub_client
export CREDHUB_SECRET=$credhub_secret
export CREDHUB_CA_CERT=$credhub_ca_cert