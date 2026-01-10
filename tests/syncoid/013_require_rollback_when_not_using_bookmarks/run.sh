#!/bin/bash

# test that a rollback is required when not using bookmarks

set -x
set -e

. ../../common/lib.sh

POOL_IMAGE="/tmp/syncoid-test-013.zpool"
MOUNT_TARGET="/tmp/syncoid-test-013.mount"
POOL_SIZE="1000M"
POOL_NAME="syncoid-test-013"
TARGET_CHECKSUM="04ac2995ea698153d294e76b73afdc4143b1a912900e979a47600a6f9ae00905  -"

truncate -s "${POOL_SIZE}" "${POOL_IMAGE}"

zpool create -m "${MOUNT_TARGET}" -f "${POOL_NAME}" "${POOL_IMAGE}"

function cleanUp {
  zpool export "${POOL_NAME}"
}

# export pool in any case
trap cleanUp EXIT

zfs create "${POOL_NAME}"/a
zfs snapshot "${POOL_NAME}"/a@s0

# This fully replicates a to b
../../../syncoid --debug --no-sync-snap --no-rollback --create-bookmark "${POOL_NAME}"/a "${POOL_NAME}"/b

echo "Test 1" > "${MOUNT_TARGET}"/a/file1
zfs snapshot "${POOL_NAME}"/a@s1

# This incrementally replicates from a@s0 to a@s1
../../../syncoid --debug --no-sync-snap --no-rollback --create-bookmark "${POOL_NAME}"/a "${POOL_NAME}"/b

echo "Test 2" > "${MOUNT_TARGET}"/a/file2
zfs snapshot "${POOL_NAME}"/a@s2

# Destroy latest common snap between a and b
zfs destroy "${POOL_NAME}"/a@s1

# This uses a@s0 and rolls b back to it although common and newer bookmark a#s1 exists
../../../syncoid --debug --no-sync-snap --no-bookmark --create-bookmark "${POOL_NAME}"/a "${POOL_NAME}"/b

echo "Test 3" > "${MOUNT_TARGET}"/a/file3
zfs snapshot "${POOL_NAME}"/a@s3

# This uses a@s2 as base snap again
../../../syncoid --debug --no-sync-snap --no-rollback --create-bookmark "${POOL_NAME}"/a "${POOL_NAME}"/b

# verify
output=$(zfs list -t snapshot -r -H -o name "${POOL_NAME}")
checksum=$(echo "${output}" | shasum -a 256)

if [ "${checksum}" != "${TARGET_CHECKSUM}" ]; then
  exit 1
fi

exit 0
