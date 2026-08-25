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
#   2. packer build into the free one of the release's two disposable slots (the
#                   one NOT holding the live template), with -force.
#   3. promote_by_name  on success only, rename that build to the canonical
#                   template name clones select by — so a failed build never
#                   touches the working template. Skipped if the build failed.
#
# PVE_DRY_RUN=1 ./build.sh resolute
#   Exercises the Proxmox API control flow (ensure_iso + publish) printing every
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

# --- Uptime Kuma heartbeat ----------------------------------------------------
# Runs ALONGSIDE the Cronitor wrapper this script is already invoked under
# (`cronitor exec <key> ./build.sh <release>` from the nightly crontab on
# ubuntu1). Cronitor stays authoritative until Kuma has been green for three
# consecutive days.
#
# Deliberately in here rather than in the crontab: the crontab is a personal
# one that is not version-controlled, whereas this file is reviewed. It also
# means the ping is per-release, matching how Cronitor is invoked — one monitor
# per release, so a Noble failure cannot mask a Resolute success.
#
# The token map is `<release> <token>` per line, root-readable only, placed by
# ansible-homelab. No token is in this repo. A missing map simply disables the
# Kuma half; the build and the Cronitor ping are unaffected.
KUMA_PUSH_MAP="${KUMA_PUSH_MAP:-/etc/kuma-push.map}"
KUMA_URL="${KUMA_URL:-https://uptime.mattconnley.com/api/push}"

kuma_ping() {
  local release="$1" status="$2" msg="${3:-}" token
  [ -r "$KUMA_PUSH_MAP" ] || return 0
  token="$(awk -v r="$release" '$1==r {print $2; exit}' "$KUMA_PUSH_MAP" 2>/dev/null)"
  [ -n "$token" ] || return 0
  # Never fail the build on a heartbeat. --cacert because uptime.mattconnley.com
  # presents a ConnleyHome-CA certificate; hosts that do not trust it otherwise
  # fail with "self-signed certificate in certificate chain" and the ping is
  # lost silently.
  curl -fsS -m 10 --retry 2 \
    ${CONNLEY_CA_FILE:+--cacert "$CONNLEY_CA_FILE"} \
    "${KUMA_URL}/${token}?status=${status}&msg=$(printf '%s' "${msg:-$status}" | sed 's/ /%20/g')" \
    >/dev/null 2>&1 || true
}

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
  slot_a=$(hcl_get "$varfile" build_vm_id_a)
  slot_b=$(hcl_get "$varfile" build_vm_id_b)
  sums_url=${iso_checksum#file:}   # iso_checksum is file:<SHA256SUMS url>

  # Pick the build slot: whichever of the two does NOT currently hold the live
  # template. If the live template is at neither (first migration, or none), use
  # slot A. This guarantees the -force build never lands on the live template.
  current=$(_pve_templates_named "$template_name" 2>/dev/null | head -n1)
  if [ "$current" = "$slot_a" ]; then
    build_vm_id="$slot_b"
  else
    build_vm_id="$slot_a"
  fi

  echo "=============================================================================="
  echo "  ${release}  ($(date '+%Y-%m-%d %H:%M:%S'))  build slot ${build_vm_id} -> ${template_name} (live: ${current:-none})"
  echo "=============================================================================="

  # 1. Pre-stage the ISO (idempotent; a hit is a no-op).
  if ! ensure_iso "$ISO_POOL" "$iso_filename" "$iso_url" "$sums_url"; then
    echo "--- ${release}: FAILED (ISO staging)" >&2
    kuma_ping "$release" down "ISO staging failed"
    failed+=("$release")
    continue
  fi

  # Dry-run: show the publish plan against current state and stop — no changes.
  if [ "$PVE_DRY_RUN" = "1" ]; then
    echo "  [dry-run] skipping packer build; showing publish plan:"
    promote_by_name "$template_name" "$build_vm_id" || true
    echo "--- ${release}: dry-run complete"
    continue
  fi

  # 2. Build into the chosen disposable slot. -force clears any leftover there
  #    (a stale -building or -old); it is never the live template's slot.
  if ! packer build \
    -var-file=common.pkrvars.hcl \
    -var-file="$varfile" \
    -var-file="$SENSITIVE" \
    -var "build_vm_id=${build_vm_id}" \
    ${PACKER_ARGS[@]+"${PACKER_ARGS[@]}"} \
    -force \
    . ; then
    echo "--- ${release}: FAILED (packer build); live template ${template_name} untouched" >&2
    kuma_ping "$release" down "packer build failed"
    failed+=("$release")
    continue
  fi

  # 3. Publish by rename, only after a verified-good build.
  if ! promote_by_name "$template_name" "$build_vm_id"; then
    echo "--- ${release}: FAILED (promote)" >&2
    kuma_ping "$release" down "promote failed"
    failed+=("$release")
    continue
  fi

  echo "--- ${release}: OK"
  kuma_ping "$release" up "template published"
done

if [ "${#failed[@]}" -ne 0 ]; then
  echo
  echo "Build failed for: ${failed[*]}" >&2
  exit 1
fi

echo
echo "All builds succeeded: ${RELEASES[*]}"
