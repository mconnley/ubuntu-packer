#!/usr/bin/env bash
##################################################################################
# Build one Proxmox template per Ubuntu release.
#
#   ./build.sh                     build every release in RELEASES
#   ./build.sh noble               build just one
#   ./build.sh noble resolute
#   ./build.sh resolute -- -var 'debug_authorized_key=...'   pass args to packer
#
# Anything after `--` is forwarded verbatim to `packer build` for every release
# named — used for debug runs (see the README's "Debugging a failed build").
# PACKER_ON_ERROR is read by packer itself, so `PACKER_ON_ERROR=ask ./build.sh
# resolute` needs nothing special here.
#
# Runs unattended nightly on ubuntu1. Design constraints that follow from that:
#
#   * Releases build SEQUENTIALLY. The autoinstall uses a fixed build-time IP
#     (see vm_boot_command in common.pkrvars.hcl), so two concurrent builds would
#     collide on it.
#   * A failure in one release does not skip the others, but the script still
#     exits non-zero so the caller — cron, a systemd unit, Cronitor — sees it.
#   * Output is prefixed per release so a scrollback of two builds is readable.
##################################################################################

set -uo pipefail

# Run from the repo root regardless of how the script was invoked, so the
# relative var-file paths below resolve.
cd "$(dirname "$0")"

# Split arguments at `--`: releases before it, pass-through packer args after.
RELEASES=()
PACKER_ARGS=()
seen_sep=0
for arg in "$@"; do
  if [ "$seen_sep" -eq 0 ] && [ "$arg" = "--" ]; then
    seen_sep=1
    continue
  fi
  if [ "$seen_sep" -eq 0 ]; then
    RELEASES+=("$arg")
  else
    PACKER_ARGS+=("$arg")
  fi
done

# Default to all releases when none were named.
if [ "${#RELEASES[@]}" -eq 0 ]; then
  RELEASES=(noble resolute)
fi

if [ ! -f sensitive.pkrvars.hcl ]; then
  echo "ERROR: sensitive.pkrvars.hcl is missing. Copy sensitive.pkrvars.hcl.example and fill it in." >&2
  exit 1
fi

failed=()

for release in "${RELEASES[@]}"; do
  varfile="releases/${release}.pkrvars.hcl"

  if [ ! -f "$varfile" ]; then
    echo "ERROR: no such release '${release}' (expected ${varfile})" >&2
    failed+=("$release")
    continue
  fi

  echo "=============================================================================="
  echo "  Building ${release}  ($(date '+%Y-%m-%d %H:%M:%S'))"
  echo "=============================================================================="

  # -force replaces the existing template at the release's pinned VMID rather
  # than leaking a new VM every night. PACKER_ARGS is any pass-through given
  # after `--`; the "${PACKER_ARGS[@]+...}" form is safe under `set -u` when it
  # is empty.
  if packer build \
    -var-file=common.pkrvars.hcl \
    -var-file="$varfile" \
    -var-file=sensitive.pkrvars.hcl \
    ${PACKER_ARGS[@]+"${PACKER_ARGS[@]}"} \
    -force \
    . ; then
    echo "--- ${release}: OK"
  else
    echo "--- ${release}: FAILED" >&2
    failed+=("$release")
  fi
done

if [ "${#failed[@]}" -ne 0 ]; then
  echo
  echo "Build failed for: ${failed[*]}" >&2
  exit 1
fi

echo
echo "All builds succeeded: ${RELEASES[*]}"
