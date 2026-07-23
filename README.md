# ubuntu-packer

Builds the **Ubuntu Server golden images** for the homelab — Proxmox templates that
every non-Talos Linux VM is cloned from.

The build runs **unattended, nightly, on `ubuntu1`**, so a freshly cloned VM is current
the moment it hits the wire, with the standard site config already in place.

| Release | Template | VMID |
|---------|----------|------|
| Ubuntu 24.04 LTS (Noble Numbat) | `ubuntu-noble-template` | 100 |
| Ubuntu 26.04 LTS (Resolute Raccoon) | `ubuntu-resolute-template` | 500 |

## What is baked into the image

The dividing line, from
[ADR-0005](https://github.com/mconnley/homelab-gitops/blob/main/docs/adr/0005-vm-golden-images-packer-repo.md)
in `homelab-gitops`:

> **Bake it into the image only if it must be true before Ansible can reach the host.**
> Everything else belongs in `ansible-homelab`.

So this repo owns: the `ansible` user and its authorized key, the `ConnleyHome-CA` trust
anchor, `qemu-guest-agent`, the disk layout, the NTP source, the NFS mounts, the base
package set, and the cloud-init/machine-id reset. Day-2 configuration, service setup and
drift correction are Ansible's, not this repo's.

Kubernetes nodes are **not** built here — Talos nodes come from Talos factory images and
the `talos-configs` repo.

## Usage

```sh
./build.sh                 # every release, sequentially
./build.sh noble           # just one
./build.sh noble resolute
```

Builds run sequentially by design: the autoinstall uses a fixed build-time IP
(`192.168.2.233`), so concurrent builds would collide on it. `build.sh` exits non-zero if
any release fails, and still attempts the rest.

Each release runs three steps (see [How a build is published](#how-a-build-is-published)):
`ensure_iso` pre-stages the installer ISO in the pool, `packer build` builds into a
disposable VMID, and `promote` publishes that onto the production VMID **only on success**.

### Prerequisites

1. **`sensitive.pkrvars.hcl`** — copy the example and fill it in. It is gitignored.

   ```sh
   cp sensitive.pkrvars.hcl.example sensitive.pkrvars.hcl
   ```

2. **The internal root CA** at `files/secure/homelabrootcert.crt` (also gitignored).

3. **Packer ≥ 1.10**, plus `packer init .` once to fetch the Proxmox plugin.

## Layout

```
build.sh                         orchestrates ensure_iso -> packer build -> promote
ubuntu.pkr.hcl                   one source + one build, parameterized by release
variables.pkr.hcl                variable declarations and documentation
common.pkrvars.hcl               settings shared by every release
releases/
  noble.pkrvars.hcl              per-release: ISO, filename, template name, build/prod VMIDs
  resolute.pkrvars.hcl
http/user-data.pkrtpl.hcl        the autoinstall, shared by every release
scripts/setup_ubuntu.sh          provision, harden, generalize, verify (runs in the guest)
scripts/pve-api.sh               Proxmox API helpers: ensure_iso + promote (run on ubuntu1)
files/                           configuration copied into the image
sensitive.pkrvars.hcl.example    the credential contract
docs/modernization-plan.md       rationale for the current structure
```

### Adding a release

Drop a new file in `releases/` (copy an existing one; set `iso_url`, `iso_filename`,
`template_name`, and a unique `build_vm_id`/`template_vm_id` pair), add its codename to the
default `RELEASES` in `build.sh`, and to the CI matrix. Nothing else should need to change.

There is deliberately **one** source block rather than one per release. Packer's
build-block source overrides can only set top-level attributes, and the ISO lives in the
nested `boot_iso` block, so a per-release ISO cannot be expressed that way. Parameterizing
a single source keeps duplication at zero.

## How a build is published

`build.sh` never builds directly onto the template that clones use. Per release it holds
two VMIDs:

- **`build_vm_id`** (e.g. `9500`) — disposable. Packer builds here with `-force`.
- **`template_vm_id`** (e.g. `500`) — the production template clones use.

On a **successful** build, `promote` (in `scripts/pve-api.sh`) publishes the build onto
production: it deletes the old `template_vm_id`, full-clones `build_vm_id` onto it, and
marks it a template. On a **failed** build, promote never runs, so the working template is
untouched. This is why a failed nightly can no longer leave you without a template — the
old failure mode where `-force` on a fixed VMID destroyed the template up front is gone.

**Fail-safety:** promote refuses to touch production unless the freshly built template is
confirmed present, and it leaves `build_vm_id` in place afterwards as a fallback. The only
residual window is the seconds-to-minutes of the full clone (production briefly empty),
and it happens only *after* a verified-good build. If the clone step itself fails, the
build template still exists and promote prints the one-line `qm clone` recovery command.

> This assumes clones reference the template by **VMID**. If you clone by **name**, a
> zero-window blue/green variant (build to an alternate VMID, then rename-swap) is
> possible — say so and it's a small change.

**ISO caching.** `ensure_iso` stores each installer ISO in the pool under its stable
basename (`iso_filename`) via Proxmox's server-side `download-url`, and Packer boots it
with `iso_file`. So the 2.7 GB ISO is fetched **once** and reused every night; a
point-release bump changes `iso_filename`, misses the cache, and pulls the new one
automatically. (Previously Packer re-downloaded and re-uploaded it every run.)

### Dry-run the Proxmox side first

`ensure_iso` and `promote` make real Proxmox API calls, and they need a token with more
than build permissions — at least `Datastore.Allocate*` (ISO download) and
`VM.Clone`/`VM.Allocate` (clone + delete). Before trusting the nightly cron, dry-run once:

```sh
PVE_DRY_RUN=1 ./build.sh resolute
```

This prints every mutating API call instead of making it (and skips the packer build), so
you can confirm the VMIDs and the plan. If your build token lacks the permissions, a real
run fails at `ensure_iso` or `promote` — and because promote is fail-safe, the production
template is left intact.

## Credentials

No credential is committed, and the build user has none worth stealing:

- **`packer`** (build user) — password is regenerated per run (`uuidv4`), injected into
  the autoinstall over Packer's in-memory HTTP server, and the account is deleted in the
  SEAL section of `scripts/setup_ubuntu.sh`. Nothing is stored, and there is no committed
  hash to keep in sync.

  > The deletion lives in the provisioning script, not a `shutdown_command`, because
  > **the `proxmox-iso` builder does not support `shutdown_command`** — it powers the VM
  > off through the Proxmox API. `setup_ubuntu.sh` is the last code that runs inside the
  > guest, so it is the last opportunity. `packer validate` rejects the option outright,
  > which is one reason CI runs it.
- **`matt`** and **`ansible`** — key only, no password in the image. Public keys are in
  `common.pkrvars.hcl`; public keys are not secrets.

`matt`'s console password is deliberately **not** baked in. A password in an image cannot
be rotated without a rebuild-and-reclone, and this repo previously demonstrated the
failure mode by shipping the same hash for years. It belongs post-boot, in
`ansible-homelab`'s `configure_users` role, sourced from OpenBao.

> **Break-glass trade-off:** between a clone's first boot and its first Ansible run, no
> account can log in at the Proxmox console — only over SSH by key. Recovery on a clone
> with broken networking means a GRUB edit (`init=/bin/bash`). If you would rather trade
> that back, add a `passwd:` line for `matt` in `http/user-data.pkrtpl.hcl` with a hash
> from `openssl passwd -6`, and re-add a `matt_password_hash` sensitive variable.

The image ships with `PasswordAuthentication no` and `PermitRootLogin no`. Password auth
is enabled only for the duration of the build and reverted by `setup_ubuntu.sh` before
sealing — without reloading sshd, so the running session survives long enough to shut the
VM down cleanly.

> **History:** before 2026-07, the `packer` and `matt` password hashes were committed to
> this public repo, and the build user was never actually deleted — its `userdel` lived in
> a `vm_shutdown_command_text` variable that nothing referenced, and the builder would not
> have supported it anyway. Both are fixed, but any hash visible in git history before
> that date should be treated as public forever.

## Debugging a failed build

Because the build user's password is a per-run `uuidv4` that is never stored, a failed
build cannot normally be logged into. How you diagnose one depends on **which phase**
failed — and the two phases need different tools.

**Provisioning phase** (after first boot, while `setup_ubuntu.sh` runs). The installed
system and the `packer` user exist, so SSH works — once you authorize a key and stop
Packer from tearing the VM down:

```sh
PACKER_ON_ERROR=ask ./build.sh resolute -- \
  -var "debug_authorized_key=$(cat ~/.ssh/id_ed25519.pub)"
```

Everything after `--` is forwarded to `packer build`; `PACKER_ON_ERROR` is read by
Packer directly.

On failure, `PACKER_ON_ERROR=ask` leaves the VM running (choose to keep it at the
prompt). `debug_authorized_key` authorizes your key on the **build user only**, so:

```sh
ssh -o IdentitiesOnly=yes -i ~/.ssh/id_ed25519 packer@192.168.2.233
```

`debug_authorized_key` is empty in every normal build, so nothing is baked in; and even
when set, the key dies with the build user at seal time, so it never reaches a clone. Do
**not** commit it to `common.pkrvars.hcl` — pass it with `-var` for the debug run only.

**Installer phase** (subiquity, before first boot — e.g. an out-of-space during install).
There is **no installed system to SSH into**, and the installer's own sshd is stopped by
`early-commands`, so `debug_authorized_key` cannot help here. Instead:

- Run with `PACKER_ON_ERROR=ask` so the VM is not destroyed.
- Open the VM's **console in Proxmox**. A failed subiquity run offers a shell; from it,
  `df -h` shows a full `/target`, and `/var/log/installer/` (`subiquity-server-debug.log`,
  `curtin-install.log`) has the detail.
- The usual culprit is a too-small `vm_disk_size` — see the note on that variable.

## Ubuntu 26.04 notes

Two changes in Resolute affect this build; both are handled in shared code:

- **`sudo-rs` replaces `sudo`.** It does not support `-E`/`--preserve-env`
  ([sudo-rs#1299](https://github.com/trifectatechfoundation/sudo-rs/issues/1299), open),
  so the provisioner uses `sudo env {{.Vars}}` rather than `sudo -E`. Correct on every
  release.
- **uutils replaces GNU coreutils** at roughly 88% test-suite parity. Only basic
  invocations are used, and `set -euo pipefail` turns any surprise into a failed build.

Verified unchanged: the `/casper/vmlinuz` + `/casper/initrd` boot paths, the `autoinstall`
kernel argument, and the subiquity `version: 1` schema. Post-quantum SSH defaults are a
non-issue for Packer's Go SSH client.

## CI

`.github/workflows/validate.yml` runs `packer fmt -check`, `packer validate` for each
release, and `shellcheck`. It exists because of a specific past failure: a variable that
was set but referenced by nothing, which silently left the build user in every clone.

## Open items

- **Checkmk registration.** The agent package is installed into the image, but
  `files/postbuild_job.sh` — which registers the host with the Checkmk server on first
  boot — is staged at `/usr/local/bin/` and **nothing invokes it** on Proxmox. Its only
  callers were a VMware customization spec and a Rancher cloud-config, both since removed.
  It also bakes Checkmk API credentials into every image. Registration is host-specific,
  post-boot work that belongs in `ansible-homelab` (which already has a `checkmk_agent`
  role, currently used only for `dns_servers` and `flow_probes`). Left functionally
  as-is pending that decision rather than silently changed.
- **The nightly schedule lives in the crontab, not this repo.** It runs from matt's
  crontab on `ubuntu1` (`cronitor exec <key> ./build.sh <release>`, releases 2h apart so
  the fixed build IP never collides). Under ADR-0005 the schedule is host config and would
  ideally move to an `ansible-homelab`-managed systemd timer.
- **Consider key-based auth for the build user**, removing password auth from the
  installer entirely.
- **Stale branches.** This repo now works trunk-based on `main`. `develop` is 25 commits
  behind and unused, and `feature/ansible-setup` is fully merged; both can be deleted
  locally and on the remote.
