#!/bin/bash
set -eu

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

if [ "$(docker images -q "platform-automation-image:${pa_latest_version}")" == "" ]; then
  pivnet download-product-files \
    --product-slug=platform-automation \
    --release-version="$pa_latest_version" \
    --glob='platform-automation-image-*.tgz' \
    --download-dir="${temp_dir}/"

  # Need to have the file path glob so we can exclude the version
  # shellcheck disable=SC2086
  docker import ${temp_dir}/platform-automation-image-*.tgz "platform-automation-image:${pa_latest_version}"
fi