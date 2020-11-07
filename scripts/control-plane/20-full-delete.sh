#!/bin/bash
set -eu

res1=$(date +%s.%N)

[ -z "${IAAS:-}" ] && echo '$IAAS must be set' && exit 2
repo_root="$(cd "$(dirname "$0")/../.." && pwd)"
${repo_root}/scripts/control-plane/21-delete-concourse.sh
${repo_root}/scripts/control-plane/22-delete-opsman.sh
${repo_root}/scripts/control-plane/23-delete-terraform.sh

res2=$(date +%s.%N)
dt=$(echo "$res2 - $res1" | bc)
dd=$(echo "$dt/86400" | bc)
dt2=$(echo "$dt-86400*$dd" | bc)
dh=$(echo "$dt2/3600" | bc)
dt3=$(echo "$dt2-3600*$dh" | bc)
dm=$(echo "$dt3/60" | bc)
ds=$(echo "$dt3-60*$dm" | bc)

LC_NUMERIC=C printf "Total runtime: %d:%02d:%02d:%02.4f\n" $dd $dh $dm $ds