#!/bin/bash
set -eu

res1=$(date +%s.%N)

[ -z "${IAAS:-}" ] && echo '$IAAS must be set' && exit 2
[ -z "${PIVNET_TOKEN:-}" ] && echo '$PIVNET_TOKEN must be set' && exit 2

repo_root="$(cd "$(dirname "$0")/../.." && pwd)"

${repo_root}/scripts/control-plane/01-prepare-docker.sh
${repo_root}/scripts/control-plane/02-apply-terraform.sh

echo "Pausing execution while you add a DNS entry for the following hosted zone:"
${repo_root}/scripts/util/10-print-om-var.sh "dns_zone_name"
echo "With the following Name Servers:"
${repo_root}/scripts/util/10-print-om-var.sh "dns_zone_name_servers"
read -p "Press [enter] key to resume Contol Plane deployment once DNS is resolving ..."

${repo_root}/scripts/control-plane/03-deploy-opsman.sh
${repo_root}/scripts/control-plane/04-update-bosh-releases.sh
${repo_root}/scripts/control-plane/05-deploy-concourse.sh

res2=$(date +%s.%N)
dt=$(echo "$res2 - $res1" | bc)
dd=$(echo "$dt/86400" | bc)
dt2=$(echo "$dt-86400*$dd" | bc)
dh=$(echo "$dt2/3600" | bc)
dt3=$(echo "$dt2-3600*$dh" | bc)
dm=$(echo "$dt3/60" | bc)
ds=$(echo "$dt3-60*$dm" | bc)

LC_NUMERIC=C printf "Total runtime: %d:%02d:%02d:%02.4f\n" $dd $dh $dm $ds