#!/usr/bin/env bash
##################################################################################
# Build one Proxmox template per Ubuntu release, safely.
#
#   ./build.sh                     build every release in RELEASES
#   ./build.sh noble               build just one
#   ./build.sh noble resolute
#   ./build.sh resolute -- -var 'debug_authorized_key=...'   pass args to packer
#
# Per release, three steps:
#   1. ensure_iso   pre-stage the ISO in the pool under a stable name, so Packer
#                   boots it via iso_file and nothing re-downloads 2.7 GB nightly.
#   2. packer build to a DISPOSABLE build_vm_id (with -force).
#   3. promote      on success only, publish that build onto the production
#                   template_vm_id — so a failed build never harms the working
#                   template. Skipped if the build failed.
#
# PVE_DRY_RUN=1 ./build.sh resolute
#   Exercises the Proxmox API control flow (ensure_iso + promote) printing every
#   mutating call instead of making it, and SKIPS the packer build. Run this once
#   before trusting the nightly cron — see the README.
#
# Anything after `--` is forwarded verbatim to `packer build`. PACKER_ON_ERROR is
# read by packer itself, so `PACKER_ON_ERROR=ask ./build.sh resolute` just works.
#
# Runs unattended nightly on ubuntu1. Releases build SEQUENTIALLY: the autoinstall
# uses a fixed build-time IP (see vm_boot_command), so two builds must not overlap.
# A failure in one release does not skip the others, but the script exits non-zero
# so the caller — cron, Cronitor — sees it.
##################################################################################

set -uo pipefail

cd "$(dirname "$0")"

# shellcheck source=scripts/pve-api.sh
. scripts/pve-api.sh

SENSITIVE="sensitive.pkrvars.hcl"

# --- Split args at `--`: releases before, pass-through packer args after ------
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
if [ "${#RELEASES[@]}" -eq 0 ]; then
  RELEASES=(noble resolute)
fi

if [ ! -f "$SENSITIVE" ]; then
  echo "ERROR: ${SENSITIVE} is missing. Copy sensitive.pkrvars.hcl.example and fill it in." >&2
  exit 1
fi

# --- Read a `key = "value"` or `key = number` line from an HCL var file --------
# Tolerates surrounding whitespace, quotes, and trailing `# comments`.
hcl_get() {
  local file="$1" key="$2" line val
  line=$(grep -E "^[[:space:]]*${key}[[:space:]]*=" "$file" | head -n1) || return 1
  val=${line#*=}
  val=${val%%#*}
  val=$(printf '%s' "$val" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' -e 's/^"//' -e 's/"$//')
  printf '%s' "$val"
}

# --- Proxmox API connection, from sensitive.pkrvars.hcl -----------------------
# Exported for pve-api.sh. proxmox_url is already the .../api2/json base.
PVE_API_URL=$(hcl_get "$SENSITIVE" proxmox_url)
PVE_NODE=$(hcl_get "$SENSITIVE" proxmox_node)
PVE_TOKEN_ID=$(hcl_get "$SENSITIVE" proxmox_username)
PVE_TOKEN_SECRET=$(hcl_get "$SENSITIVE" proxmox_token)
ISO_POOL=$(hcl_get "$SENSITIVE" iso_storage_pool)
VM_POOL=$(hcl_get "$SENSITIVE" vm_storage_pool)
export PVE_API_URL PVE_NODE PVE_TOKEN_ID PVE_TOKEN_SECRET
export PVE_INSECURE="${PVE_INSECURE:-0}"
export PVE_DRY_RUN="${PVE_DRY_RUN:-0}"

for v in PVE_API_URL PVE_NODE PVE_TOKEN_ID PVE_TOKEN_SECRET ISO_POOL VM_POOL; do
  [ -n "${!v}" ] || { echo "ERROR: could not read ${v} from ${SENSITIVE}" >&2; exit 1; }
done

failed=()

for release in "${RELEASES[@]}"; do
  varfile="releases/${release}.pkrvars.hcl"
  if [ ! -f "$varfile" ]; then
    echo "ERROR: no such release '${release}' (expected ${varfile})" >&2
    failed+=("$release")
    continue
  fi

  iso_url=$(hcl_get "$varfile" iso_url)
  iso_checksum=$(hcl_get "$varfile" iso_checksum)
  iso_filename=$(hcl_get "$varfile" iso_filename)
  template_name=$(hcl_get "$varfile" template_name)
  build_vm_id=$(hcl_get "$varfile" build_vm_id)
  template_vm_id=$(hcl_get "$varfile" template_vm_id)
  sums_url=${iso_checksum#file:}   # iso_checksum is file:<SHA256SUMS url>

  echo "=============================================================================="
  echo "  ${release}  ($(date '+%Y-%m-%d %H:%M:%S'))  build ${build_vm_id} -> template ${template_vm_id}"
  echo "=============================================================================="

  # 1. Pre-stage the ISO (idempotent; a hit is a no-op).
  if ! ensure_iso "$ISO_POOL" "$iso_filename" "$iso_url" "$sums_url"; then
    echo "--- ${release}: FAILED (ISO staging)" >&2
    failed+=("$release")
    continue
  fi

  # Dry-run: exercise the promote control flow and stop — no packer, no changes.
  if [ "$PVE_DRY_RUN" = "1" ]; then
    echo "  [dry-run] skipping packer build; showing promote plan:"
    promote "$build_vm_id" "$template_vm_id" "$template_name" "$VM_POOL" || true
    echo "--- ${release}: dry-run complete"
    continue
  fi

  # 2. Build into the disposable vmid. -force clears a leftover build vmid.
  if ! packer build \
    -var-file=common.pkrvars.hcl \
    -var-file="$varfile" \
    -var-file="$SENSITIVE" \
    ${PACKER_ARGS[@]+"${PACKER_ARGS[@]}"} \
    -force \
    . ; then
    echo "--- ${release}: FAILED (packer build); production template ${template_vm_id} untouched" >&2
    failed+=("$release")
    continue
  fi

  # 3. Publish onto production only after a verified-good build.
  if ! promote "$build_vm_id" "$template_vm_id" "$template_name" "$VM_POOL"; then
    echo "--- ${release}: FAILED (promote)" >&2
    failed+=("$release")
    continue
  fi

  echo "--- ${release}: OK"
done

if [ "${#failed[@]}" -ne 0 ]; then
  echo
  echo "Build failed for: ${failed[*]}" >&2
  exit 1
fi

echo
echo "All builds succeeded: ${RELEASES[*]}"
