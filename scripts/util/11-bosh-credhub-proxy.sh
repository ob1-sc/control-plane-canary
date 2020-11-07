#!/bin/bash
[ -z "$REPO_LOCATION" ] && echo '$REPO_LOCATION must be set' && exit 2
repo_root=${REPO_LOCATION}

# get terraform output vars
terraform_outputs=$(terraform output -state="${repo_root}/state/terraform.tfstate" stable_config_opsmanager)

export OM_KEY=om.pem
echo ${terraform_outputs} | jq -r .ops_manager_ssh_private_key > $OM_KEY
chmod 0600 $OM_KEY

OM_TARGET=$(echo $terraform_outputs | jq -r .ops_manager_dns)
OM_USERNAME=admin
OM_PASSWORD=$(echo $terraform_outputs | jq -r .ops_manager_password)

CREDS=$(om -t $OM_TARGET -u $OM_USERNAME -p $OM_PASSWORD --skip-ssl-validation curl --silent \
    -p /api/v0/deployed/director/credentials/bosh_commandline_credentials | \
  jq -r .credential | sed 's/bosh //g')

echo $CREDS

# # this will set BOSH_CLIENT, BOSH_ENVIRONMENT, BOSH_CLIENT_SECRET, and BOSH_CA_CERT
# # however, BOSH_CA_CERT will be a path that is only valid on the OM VM
array=($CREDS)
for VAR in ${array[@]}; do
  export $VAR
done

export BOSH_CA_CERT="$(om -t $OM_TARGET -u $OM_USERNAME -p $OM_PASSWORD --skip-ssl-validation certificate-authorities -f json | \
    jq -r '.[] | select(.active==true) | .cert_pem')"

export BOSH_ALL_PROXY="ssh+socks5://ubuntu@$OM_TARGET:22?private-key=$OM_KEY"
export CREDHUB_PROXY=$BOSH_ALL_PROXY
export CREDHUB_CLIENT=$BOSH_CLIENT
export CREDHUB_SECRET=$BOSH_CLIENT_SECRET
export CREDHUB_CA_CERT=$BOSH_CA_CERT
export CREDHUB_SERVER="https://$BOSH_ENVIRONMENT:8844"