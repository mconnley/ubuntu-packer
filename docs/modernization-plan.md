# ubuntu-packer — modernization plan + Ubuntu 26.04 support

_Status: **implemented** 2026-07-22, except where noted under "Not done"._
_Kept as the rationale record for the current structure._

## Context

This repo runs **unattended, daily, on `ubuntu1` (192.168.2.56)** so that a freshly cloned
VM is current the moment it hits the wire. Two consequences drive everything below:

1. **Silent failure is the main risk.** A daily job nobody watches, producing a template
   nobody validates, is a stale-template generator the day it breaks. Several findings
   here are only serious *because* the build is unattended.
2. **Freshness work belongs at build time, not clone time.** Anything that can be pulled
   forward into the image (updates, mirrors) should be.

Verified on `ubuntu1`: Packer **v1.15.4** installed, host is Ubuntu 24.04.4. No
`/etc/cron.d` entry and no systemd timer invokes the build — the schedule is presumably a
user crontab under a non-`claude-diag` account, so it is **captured in no repo**
(see F13).

## Findings

Severity: **P1** act now · **P2** correctness / dead code · **P3** unattended-build
robustness · **P4** polish.

### P1 — the `packer` user survives into every clone, and its hash is public

`vm_shutdown_command_text` (`ubuntu.pkrvars.hcl:15`) carries the `userdel -rf packer`
cleanup, but **`ubuntu.pkr.hcl` never sets `shutdown_command`** — the variable is
referenced nowhere. The other two places that delete the user
(`customization_spec_script.sh`, `scripts/cloud-config.yaml`) are VMware and Rancher
leftovers wired into nothing. Compounding it:

- The repo is **public** (`gh repo view` → `PUBLIC`), and `http/noble/user-data` commits
  the SHA-512 crypt hash for `packer`.
- `late-commands` sets `PasswordAuthentication yes` and `PermitRootLogin yes`
  *permanently* in the image — the build-time loosening is never reverted.
- `packer` has `NOPASSWD:ALL`.

So every VM cloned from the template plausibly carries a sudo-capable account whose hash
is publicly downloadable, reachable over password SSH.

**Correction to a prior assumption:** the passwords are **not** plain strings in
`user-data` — they are SHA-512 crypt hashes — and **nothing in `ansible-homelab` rotates
them.** The role that sets a user password (`configure_users`, via `system_user_password`
from OpenBao) is invoked only by `playbooks/proxmox_config.yml`, whose target is
`hosts: proxmox`. No playbook applies it to `ubuntu_vms` or `linux`. The only playbook
targeting `linux` that touches users is `bootstrap_ansible_user.yml`, and it manages the
`ansible` user's key — no passwords. Treat both hashes as live and unrotated.

Nuance worth keeping: `matt`'s committed hash *is* effectively dead, because the build
overwrites it (`echo 'matt:${var.matt_password}' | sudo chpasswd`) from
`sensitive.pkrvars.hcl`. `packer`'s hash is the live credential — `var.ssh_password` must
match it for Packer's SSH to connect.

**Fix (F1):**
- Remove the `packer` user for real. _Implementation note: `shutdown_command` was the
  obvious hook, and the caution above turned out to be warranted — the `proxmox-iso`
  builder **does not support `shutdown_command` or `shutdown_timeout`** at all
  (`packer validate` rejects both as unsupported arguments; it powers the VM off through
  the Proxmox API). The deletion therefore lives in the SEAL section of
  `setup_ubuntu.sh`, the last code that runs inside the guest._
- Revert the sshd loosening at the end of `setup_ubuntu.sh` — `PermitRootLogin no`,
  `PasswordAuthentication no` — so the image ships hardened and the loosening lives only
  as long as the build.
- Move both hashes out of the tracked tree (F2), then **rotate `packer` and `matt`
  passwords** and update `sensitive.pkrvars.hcl`. Git history rewriting is pointless here;
  assume the old hashes are public forever.

### P1 — F2: template the autoinstall so no credential is tracked

Switch the builder from `http_directory` to **`http_content`**, generating `user-data`
from a `templatefile()` with the hashes injected from `sensitive.pkrvars.hcl`
(`bcrypt`/`sha512` hashes as new sensitive vars). `http_content` is a documented
proxmox-iso option.

This kills three birds: no secrets in a public repo, one autoinstall template instead of
one per release, and the `matt`/`packer` password becomes a single source of truth
(dropping the `chpasswd` + `passwd -u` fixup entirely).

### P2 — F3: the `99-disable-network-config.cfg` dance is a no-op

The build copies the file to `/etc/cloud/cloud.cfg.d/99-disable-network-config.cfg`
(provisioners 3–4), and then `setup_ubuntu.sh` — the last provisioner — runs
`rm /etc/cloud/cloud.cfg.d/*.cfg -f`, which deletes it again. Two provisioners and a
tracked file that accomplish nothing. Since Proxmox-generated cloud-init *should* own
clone networking, the deletion is the behaviour you want; the file is the mistake.

**Fix:** delete `files/99-disable-network-config.cfg` and its two provisioners.

Related: that same `rm -f *.cfg` also removes `90_dpkg.cfg`, which pins
`datasource_list`. Without it cloud-init probes every datasource on first boot. Replace
with an explicit `99-pve.cfg` containing `datasource_list: [NoCloud, ConfigDrive]` —
the Proxmox-recommended practice — and use `cloud-init clean --logs --seed`.

### P2 — F4: delete Jammy

Per operator decision, no more Jammy builds. `iso_url` / `iso_checksum` (pointing at
22.04.5) are referenced by no source block — dead vars that read as live. Remove the two
variables and their var-file entries.

### P2 — F5: dead variables and dead files

Never referenced in `ubuntu.pkr.hcl`: `vm_shutdown_timeout`, `iso_path`, `iso_file`,
`vm_network_card`, plus `iso_url` / `iso_checksum` (F4) and `vm_shutdown_command_text`
(F1 — to be wired, not deleted). `vm_disk_format` is declared and its usage is commented
out in the source block.

Dead files: `customization_spec_script.sh` (VMware customization spec — the platform is
gone), `scripts/cloud-config.yaml` (references `/home/rancher/provisioned`; Rancher is
gone). Both contain the `deluser packer` that misleadingly *looks* like the cleanup for
F1. Delete them.

### P2 — F6: `BUILD_USERNAME` is passed and never read

`environment_vars = ["BUILD_USERNAME=${var.ssh_username}"]` — `setup_ubuntu.sh` never
references it. Drop it (and see F8, which makes env-var passing fragile on 26.04 anyway).

### P3 — F7: the pinned ISO URL is the daily build's main failure mode

`iso_url_noble` pins `24.04.4`. When 24.04.5 lands, the old file is removed from
`releases.ubuntu.com` and the daily build starts 404ing — silently, since nothing watches
it. Two-part fix:

- Set `iso_checksum = "file:https://releases.ubuntu.com/24.04/SHA256SUMS"`. Packer
  supports `file:<url>` checksums and matches on the ISO filename, so **checksum**
  maintenance disappears. Be honest about the limit: the **filename** still carries the
  point release, so the URL still needs a bump twice a year. This makes the failure loud
  and one-line-fixable rather than requiring a checksum hunt.
- Add failure alerting (F14).

### P3 — F8: Ubuntu 26.04 replaces `sudo` with `sudo-rs`, which does not support `-E`

The provisioner uses:

```hcl
execute_command = "echo '${var.ssh_password}' | {{.Vars}} sudo -S -E bash '{{.Path}}'"
```

Ubuntu 26.04 ships **sudo-rs** as the default `sudo`, and
[trifectatechfoundation/sudo-rs#1299](https://github.com/trifectatechfoundation/sudo-rs/issues/1299)
("Add support for `-E` / `--preserve-env`") is **still open** as of 2026-06-23. Secondary
reports conflict on whether `-E` errors or is silently ignored; either way `{{.Vars}}`
placed before `sudo` will not survive into the script.

**Fix:** move to the implementation-agnostic idiom, which is correct on both releases:

```hcl
execute_command = "echo '${var.ssh_password}' | sudo -S env {{.Vars}} bash '{{.Path}}'"
```

### P3 — F9: build from a mirror on the right continent

`http/noble/user-data` sets the primary APT mirror to
`http://ro.archive.ubuntu.com/ubuntu/` — **`ro` is Romania.** For a daily build in
Chicago that is a slow install and a pointless transatlantic pull, almost certainly a
copy-paste artifact.

**Fix:** adopt the modern `mirror-selection` form with `country-mirror`, which lets the
installer geolocate and fall back:

```yaml
apt:
  mirror-selection:
    primary:
      - country-mirror
      - uri: "http://archive.ubuntu.com/ubuntu"
```

The legacy `primary:` list still works but is superseded.

### P3 — F10: use `updates: all` — it is exactly this project's goal

Autoinstall's `updates` key defaults to `security` (the `-security` pocket only).
Setting `updates: all` pulls `-security` **and** `-updates` during installation. That is
the repo's entire reason for existing, expressed in one line, and it lets the
`apt-get upgrade` late-command and part of `setup_ubuntu.sh`'s `dist-upgrade` retire.

### P3 — F11: uutils coreutils (26.04) — low risk, worth a smoke check

26.04 ships **uutils** (Rust coreutils) as default, passing ~88% of the GNU test suite.
`setup_ubuntu.sh` uses only basic invocations (`truncate -s 0`, `cat`, `ln -s`, `rm -f`,
`chmod`), all of which are well inside the compatible set. No change planned; adding
`set -euo pipefail` (F12) turns any surprise into a failed build rather than a silently
broken image. GNU remains installable via `update-alternatives` if something bites.

Also noted and dismissed: 26.04's post-quantum SSH defaults. OpenSSH prefers PQ KEX but
retains classical algorithms, and Packer 1.15.4's Go SSH client negotiates fine.

### P3 — F12: the provisioning script cannot fail

`setup_ubuntu.sh` has no `set -e`. Every command failure — a 404 on the Checkmk agent, a
failed `dpkg -i` — is ignored, and the build proceeds to publish a template. For an
unattended daily job this is the difference between a loud failure and months of quietly
degraded images.

**Fix:** `set -euo pipefail`, plus `wget --fail`, plus a short post-install assertion
block (agent registered, CA present, `packer` user gone, sshd hardened) that exits
non-zero.

### P3 — F13: the schedule itself is in no repo

No `/etc/cron.d` entry and no systemd timer on `ubuntu1` runs this. Under ADR-0005 and
ADR-0001 seam (a), the *schedule* is host config and belongs in **`ansible-homelab`** —
a systemd timer + unit, not a hand-rolled crontab. Out of scope for this repo's changes,
but it should be a tracked follow-up in that repo.

### P3 — F14: no alerting, no CI

- **Alerting:** wrap the daily build in Cronitor, matching the existing homelab pattern
  (the vmnas 3-2-1 pushes already use it). This is the single highest-value item for an
  unattended job.
- **CI:** `.github/` holds only devcontainer dependabot. Add a workflow running
  `packer fmt -check -diff` and `packer validate` against both releases. That alone would
  have caught F1's unwired variable.

### P4 — F15: pin the plugin, fix the plugin label

`required_plugins { name = { ... } }` uses `name` as the plugin's local label — legal but
confusing; convention is `proxmox`. The constraint `~> 1` floats across the whole v1 line
on a daily unattended build; the current release is **v1.2.4** (2026-07-21). Tighten to
`~> 1.2` and let dependabot propose bumps.

### P4 — F16: documentation and hygiene

- README is a stub claiming **v0.11.0**; `main` has moved well past that tag. Rewrite:
  what it builds, how the daily job runs, the `sensitive.pkrvars.hcl` contract (generated
  from an `.example` file), the boundary with `ansible-homelab` (ADR-0005), and how to
  add a release.
- Add `sensitive.pkrvars.hcl.example` — the README currently documents the contract in
  prose and calls the file `sensitive.variables.pkr.hcl`, which is the wrong filename.
- **Gitflow is broken:** `develop` is **25 commits behind `main`** and 0 ahead. The
  `feature/ansible-setup` PR merged to `main` and was never back-merged. The next branch
  cut from `develop` silently reverts the NFS mounts, storage config, and Salt removal.
  Either back-merge or drop gitflow for trunk-based — for a solo repo that builds a few
  times a year, gitflow is overhead (opinion).
- `vm_disk_discard = false` on thin-provisioned storage: deleted blocks are never
  unmapped, so the pool grows monotonically. Same failure class as the Windows retrim
  issue. Recommend `true` unless there is a known reason.
- Checkmk agent is pinned to `2.4.0p17-1` in `setup_ubuntu.sh`, fetched from the live
  server. It will drift against the 192.168.2.46 server version. Either derive it from
  the server's `/check_mk/agents/` index at build time, or keep the pin and let
  dependabot-style review own it — but do it deliberately.
- Comment density: `variables.pkr.hcl` has good per-variable descriptions;
  `ubuntu.pkr.hcl` and the shell scripts have almost none. Bring the latter up to the
  same standard, documenting *why* (e.g. why the machine-id is truncated, why
  `groupdel staff`).

## Ubuntu 26.04 "Resolute Raccoon" support

Released **2026-04-23**. ISO currently `ubuntu-26.04-live-server-amd64.iso` at
`https://releases.ubuntu.com/26.04/` with `SHA256SUMS` alongside. **26.04.1 lands
2026-08-04**, which will rename the ISO — F7's `file:` checksum plus alerting is what
makes that a one-line fix instead of an outage.

Confirmed unchanged: `/casper/vmlinuz` + `/casper/initrd` boot paths, the `autoinstall`
kernel argument, and `version: 1` autoinstall schema. Confirmed changed and handled
above: sudo-rs (F8), uutils (F11).

One further schema note: from 24.04 onward, unrecognized autoinstall keys are a **fatal
validation error** in schema versions above 1 (warnings only in version 1). Staying on
`version: 1` is correct; the shared template must not accumulate speculative keys.

### Structure

The differences between the two builds are exactly: ISO URL, checksum URL, VM name, VMID,
and codename. Everything else — hardware, SSH, Proxmox connection, provisioners, the
autoinstall body — is identical and must not be duplicated.

**Packer constrains the options here.** Build-block source overrides can only set
top-level attributes, **not nested blocks** — and `boot_iso` is a nested block. So the
"one source, two build-block overrides" approach cannot express a per-release ISO. That
leaves:

- **Option A — one parameterized source, one var file per release** (recommended). Zero
  duplicated HCL. `build.sh` loops:
  `for r in noble resolute; do packer build -var-file=releases/$r.pkrvars.hcl ...; done`.
  Per-release exit codes give clean failure isolation and per-release Cronitor pings.
  Cost: `packer build .` no longer builds both in one invocation.
- **Option B — two full `source` blocks** fed by a shared `locals` map. `packer build .`
  builds both (in parallel), `-only=generic.noble` targets one. Cost: ~35 lines of
  duplicated block scaffolding.

Proposed tree under Option A:

```
ubuntu.pkr.hcl                    # one source + one build, fully parameterized
variables.pkr.hcl                 # pruned per F4/F5, commented
common.pkrvars.hcl                # hardware/SSH/shared settings (was ubuntu.pkrvars.hcl)
releases/noble.pkrvars.hcl        # iso_url, iso_checksum, vm_name, vm_id, codename
releases/resolute.pkrvars.hcl
http/user-data.pkrtpl.hcl         # ONE templated autoinstall, served via http_content
sensitive.pkrvars.hcl.example
build.sh                          # loops releases, propagates failure, pings Cronitor
docs/modernization-plan.md        # this file
.github/workflows/validate.yml    # packer fmt -check + validate
```

`http/noble/` and `http/noble/meta-data` (empty) collapse into the single template.

### Sequencing

Land in three commits, each independently verifiable:

1. **Security + dead code** (F1–F6, F15) on noble only. Rotate credentials. Verify a
   clone has no `packer` user and hardened sshd before going further.
2. **Unattended-build robustness** (F7, F9, F10, F12, F14, F16). Still noble only.
3. **Restructure + add resolute** (F8, F11, Option A/B). Build both, clone both, confirm
   Checkmk registration and Ansible reachability on a resolute clone.

## Decisions taken

1. **Structure — Option A.** One parameterized source, one var file per release.
2. **Resolute and noble coexist**, both built nightly. Noble is supported to 2029 and
   every existing VM descends from it.
3. **Legacy BIOS for resolute**, matching noble, so the release change is isolated from a
   firmware change. UEFI remains a separate, deliberate migration.
4. **`ubuntu-resolute-template`, VMID 500** — operator's choice, well clear of the
   100–142 range currently in use.
5. **`vm_disk_discard = true`.**
6. **Checkmk agent version stays pinned**, bumped in the same change that upgrades the
   server. Dependabot is explicitly not pointed at it.
7. **No account password in the image at all.** The plan proposed keeping a
   `matt_password_hash` in `sensitive.pkrvars.hcl`; instead `matt` is key-only, matching
   `ansible`. A password baked into an image cannot be rotated without a rebuild and a
   re-clone of every descendant — which is precisely how the same hash survived for years
   in this repo. It belongs in `ansible-homelab`'s `configure_users` role, from OpenBao.
   Cost: no console login on a clone until Ansible has run (see README).

## Deviation from the plan as written

F1/F2 proposed moving the `packer` password hash into `sensitive.pkrvars.hcl`. The
implementation goes further and removes the credential entirely: the build user's
password is generated per run with `uuidv4()`, injected through the in-memory
`http_content` seed, and the account is deleted at shutdown. This serves the same goal
(nothing tracked) while also eliminating the failure mode the plan would have introduced —
a plaintext `ssh_password` and a `packer_password_hash` that must be kept in sync by hand,
where a mismatch fails the build 20 minutes in with an SSH timeout.

Only `matt` now needs a stored hash.

## Not done

- **F14 (Cronitor alerting) and F13 (the schedule itself)** — both are host config on
  `ubuntu1` and belong in `ansible-homelab` under ADR-0005, not here. `build.sh` exits
  non-zero on any release failure, which is the hook they need.
- **Credential rotation.** The `matt` hash and the Checkmk automation secret should be
  rotated, since the old `matt` hash is in this public repo's history. That is an
  operator action.
- **Checkmk registration** (`files/postbuild_job.sh`) — left functionally untouched. It is
  staged into the image but nothing on Proxmox invokes it, and it bakes API credentials
  into every clone. The correct home is `ansible-homelab`'s existing `checkmk_agent` role,
  currently applied only to `dns_servers` and `flow_probes`. Changing it silently would
  have meant either starting or stopping host registration without a decision.
- **Key-based auth for the build user**, which would remove password auth from the
  installer altogether.
- **Branch cleanup** — the repo moved to trunk-based on `main` (2026-07-22). `develop`
  (25 commits behind) and the fully-merged `feature/ansible-setup` are both now stale and
  can be deleted.
