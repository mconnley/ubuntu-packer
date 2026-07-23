#!/usr/bin/env bash
##################################################################################
# Proxmox VE API helpers — sourced by build.sh.
#
# Two jobs live here, both of which happen OUTSIDE the Packer run and so cannot
# be Packer post-processors:
#
#   ensure_iso   pre-stage the install ISO in the pool under a stable name, so
#                Packer references it with iso_file and nothing re-downloads a
#                2.7 GB ISO every night (issue 2).
#
#   promote_by_name  after a successful build to a DISPOSABLE vmid, publish it by
#                RENAMING it to the canonical template name clones select by — so
#                a failed build never touches the working template (issue 1).
#
# Auth + connection come from the environment (build.sh extracts them from
# sensitive.pkrvars.hcl):
#   PVE_API_URL      e.g. https://pvehost1.example.com:8006/api2/json
#   PVE_NODE         e.g. pvehost1
#   PVE_TOKEN_ID     e.g. root@pam!packer
#   PVE_TOKEN_SECRET the token GUID
#   PVE_INSECURE     optional; 1 to skip TLS verification (default: verify)
#   PVE_DRY_RUN      optional; 1 to print mutating calls instead of making them
#
# Nothing here is destructive unless promote() runs, and promote() refuses to
# touch the production template unless the freshly built one is confirmed
# present — see the guards in promote().
##################################################################################

# --- low-level curl wrapper ---------------------------------------------------
# _pve METHOD PATH [curl args...]   ->  prints response body, returns curl status
_pve() {
  local method="$1" path="$2"
  shift 2
  local -a tls=()
  [ "${PVE_INSECURE:-0}" = "1" ] && tls=(--insecure)
  # ${tls[@]+...} guards the empty-array expansion under `set -u`.
  curl -fsSL ${tls[@]+"${tls[@]}"} \
    -H "Authorization: PVEAPIToken=${PVE_TOKEN_ID}=${PVE_TOKEN_SECRET}" \
    -X "$method" \
    "${PVE_API_URL}${path}" \
    "$@"
}

# GET, returning the `.data` payload as JSON.
_pve_get_data() { _pve GET "$1" | python3 -c 'import json,sys; print(json.dumps(json.load(sys.stdin)["data"]))'; }

# A mutating call. Honours PVE_DRY_RUN by printing instead of executing. On a
# real call, echoes the returned UPID so the caller can wait on it.
_pve_mutate() {
  local method="$1" path="$2"
  shift 2
  if [ "${PVE_DRY_RUN:-0}" = "1" ]; then
    echo "DRY-RUN: ${method} ${path} $*" >&2
    echo "UPID:dry-run:0000:0000:0000:0000:dryrun:dry:root@pam:"
    return 0
  fi
  _pve "$method" "$path" "$@" \
    | python3 -c 'import json,sys; d=json.load(sys.stdin)["data"]; print(d if isinstance(d,str) else "")'
}

# --- task polling -------------------------------------------------------------
# _pve_wait_task UPID   ->  returns 0 iff the task finished with exitstatus OK
_pve_wait_task() {
  local upid="$1"
  case "$upid" in
    UPID:dry-run:*) return 0 ;;  # nothing really happened
  esac
  local i status exitstatus
  for i in $(seq 1 240); do   # up to 240 * 5s = 20 min
    status=$(_pve_get_data "/nodes/${PVE_NODE}/tasks/${upid}/status" 2>/dev/null) || { sleep 5; continue; }
    if echo "$status" | python3 -c 'import json,sys; sys.exit(0 if json.load(sys.stdin).get("status")=="stopped" else 1)' 2>/dev/null; then
      exitstatus=$(echo "$status" | python3 -c 'import json,sys; print(json.load(sys.stdin).get("exitstatus",""))')
      [ "$exitstatus" = "OK" ] && return 0
      echo "  task ${upid} finished with exitstatus: ${exitstatus}" >&2
      return 1
    fi
    sleep 5
  done
  echo "  task ${upid} did not finish within 20 min" >&2
  return 1
}

# --- queries ------------------------------------------------------------------

# _pve_vm_exists VMID   ->  0 if a VM/template with that id exists on the node
_pve_vm_exists() {
  _pve GET "/nodes/${PVE_NODE}/qemu/$1/status/current" >/dev/null 2>&1
}

# _pve_is_template VMID -> 0 if that vmid is a template with at least one disk.
# This is the guard that makes promote() safe: we never delete production
# unless the thing we are about to publish is real.
_pve_is_template() {
  local cfg
  cfg=$(_pve_get_data "/nodes/${PVE_NODE}/qemu/$1/config" 2>/dev/null) || return 1
  echo "$cfg" | python3 -c '
import json, sys
c = json.load(sys.stdin)
is_tmpl = str(c.get("template", 0)) == "1"
has_disk = any(k.startswith(("scsi", "virtio", "sata", "ide")) and "media=cdrom" not in str(v)
               for k, v in c.items())
sys.exit(0 if (is_tmpl and has_disk) else 1)
'
}

# _pve_iso_present POOL FILENAME  ->  0 if POOL already holds an iso by that name
_pve_iso_present() {
  local pool="$1" filename="$2" data
  data=$(_pve_get_data "/nodes/${PVE_NODE}/storage/${pool}/content?content=iso" 2>/dev/null) || return 1
  echo "$data" | python3 -c '
import json, sys
want = sys.argv[1]
vols = json.load(sys.stdin)
sys.exit(0 if any(v.get("volid","").endswith("iso/"+want) for v in vols) else 1)
' "$filename"
}

# --- issue 2: pre-stage the ISO ----------------------------------------------
# ensure_iso POOL FILENAME ISO_URL SHA256SUMS_URL
#
# Idempotent. If POOL already holds FILENAME, does nothing. Otherwise has the PVE
# node download ISO_URL server-side to POOL as FILENAME, verifying the sha256
# looked up (by filename) from SHA256SUMS_URL. Because FILENAME tracks the ISO's
# basename, a point-release bump changes the name, misses the cache, and pulls
# the new one — exactly "re-pull only when the URL changes".
ensure_iso() {
  local pool="$1" filename="$2" iso_url="$3" sums_url="$4"

  if _pve_iso_present "$pool" "$filename"; then
    echo "  ISO ${pool}:iso/${filename} already present — skipping download."
    return 0
  fi

  echo "  ISO ${filename} not in ${pool}; fetching checksum and downloading server-side ..."
  local sha
  sha=$(curl -fsSL "$sums_url" | awk -v f="$filename" '$2 == "*"f || $2 == f {print $1}' | head -n1)
  if [ -z "$sha" ]; then
    echo "  ERROR: could not find ${filename} in ${sums_url}" >&2
    return 1
  fi

  local upid
  upid=$(_pve_mutate POST "/nodes/${PVE_NODE}/storage/${pool}/download-url" \
    --data-urlencode "url=${iso_url}" \
    --data-urlencode "filename=${filename}" \
    --data-urlencode "content=iso" \
    --data-urlencode "checksum=${sha}" \
    --data-urlencode "checksum-algorithm=sha256") || {
      echo "  ERROR: download-url call failed (token may lack Datastore.AllocateTemplate)" >&2
      return 1
    }
  _pve_wait_task "$upid" || { echo "  ERROR: ISO download task failed" >&2; return 1; }
  echo "  ISO ${pool}:iso/${filename} ready."
}

# --- issue 1: publish a built template onto the production vmid ----------------
# _pve_templates_named NAME  ->  prints the vmid of each template named NAME
_pve_templates_named() {
  local name="$1" data
  data=$(_pve_get_data "/nodes/${PVE_NODE}/qemu") || return 1
  echo "$data" | python3 -c '
import json, sys
want = sys.argv[1]
for vm in json.load(sys.stdin):
    if vm.get("name") == want and str(vm.get("template", 0)) == "1":
        print(vm["vmid"])
' "$name"
}

# _pve_rename VMID NEWNAME  — set a VM/template name (config change is synchronous;
# it returns null, not a UPID, so there is normally nothing to wait on).
_pve_rename() {
  local vmid="$1" newname="$2" upid
  upid=$(_pve_mutate POST "/nodes/${PVE_NODE}/qemu/${vmid}/config" --data-urlencode "name=${newname}") || return 1
  [ -n "$upid" ] && _pve_wait_task "$upid" || true
}

# _pve_delete_vm VMID
_pve_delete_vm() {
  local vmid="$1" upid
  upid=$(_pve_mutate DELETE "/nodes/${PVE_NODE}/qemu/${vmid}?purge=1&destroy-unreferenced-disks=1") || return 1
  _pve_wait_task "$upid"
}

# promote_by_name TEMPLATE_NAME BUILD_VMID
#
# Clones select the template by NAME, so publishing is a rename, not a clone:
#   1. GUARD: BUILD_VMID must be a template with a disk (else abort untouched).
#   2. retire every current "<name>" (there should be one) to "<name>-old".
#   3. rename BUILD_VMID to "<name>".
#   4. delete the retired old templates.
#
# Nothing valid is ever removed before the new template holds the name. The only
# window is the sub-second between steps 2 and 3 (briefly no "<name>"), and the
# only deletion is the now-redundant old, after the new one is live. If a later
# step fails, the worst state is a harmless duplicate the next run cleans up.
promote_by_name() {
  local name="$1" build_vmid="$2" olds o

  echo "  Publishing build ${build_vmid} as ${name} ..."

  # 1. GUARD
  if [ "${PVE_DRY_RUN:-0}" != "1" ] && ! _pve_is_template "$build_vmid"; then
    echo "  ERROR: ${build_vmid} is not a template with a disk — refusing to publish ${name}." >&2
    return 1
  fi

  # Current canonical(s), excluding the one we are about to publish.
  olds=$(_pve_templates_named "$name" 2>/dev/null | grep -vx "$build_vmid" || true)

  # 2. retire
  for o in $olds; do
    echo "  Retiring current ${name} at ${o} -> ${name}-old ..."
    _pve_rename "$o" "${name}-old" || { echo "  ERROR: could not rename ${o}; ${name} left in place." >&2; return 1; }
  done

  # 3. publish
  echo "  Renaming ${build_vmid} -> ${name} ..."
  _pve_rename "$build_vmid" "$name" || { echo "  ERROR: could not rename ${build_vmid} to ${name}." >&2; return 1; }

  # 4. delete the retired old templates (redundant now the new one is live)
  for o in $olds; do
    echo "  Deleting retired template ${o} ..."
    _pve_delete_vm "$o" || echo "  WARNING: could not delete retired ${o}; remove it manually." >&2
  done

  echo "  Published ${name} at vmid ${build_vmid}."
}
