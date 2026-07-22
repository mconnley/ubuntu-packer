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

### Prerequisites

1. **`sensitive.pkrvars.hcl`** — copy the example and fill it in. It is gitignored.

   ```sh
   cp sensitive.pkrvars.hcl.example sensitive.pkrvars.hcl
   ```

2. **The internal root CA** at `files/secure/homelabrootcert.crt` (also gitignored).

3. **Packer ≥ 1.10**, plus `packer init .` once to fetch the Proxmox plugin.

## Layout

```
ubuntu.pkr.hcl                   one source + one build, parameterized by release
variables.pkr.hcl                variable declarations and documentation
common.pkrvars.hcl               settings shared by every release
releases/
  noble.pkrvars.hcl              per-release: ISO, checksum, template name, VMID
  resolute.pkrvars.hcl
http/user-data.pkrtpl.hcl        the autoinstall, shared by every release
scripts/setup_ubuntu.sh          provision, harden, generalize, verify
files/                           configuration copied into the image
sensitive.pkrvars.hcl.example    the credential contract
docs/modernization-plan.md       rationale for the current structure
```

### Adding a release

Drop a new file in `releases/` and add its codename to `RELEASES` in `build.sh` and to
the CI matrix. Nothing else should need to change — that is the point of the structure.

There is deliberately **one** source block rather than one per release. Packer's
build-block source overrides can only set top-level attributes, and the ISO lives in the
nested `boot_iso` block, so a per-release ISO cannot be expressed that way. Parameterizing
a single source keeps duplication at zero.

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
- **The nightly schedule is in no repo.** No `/etc/cron.d` entry or systemd timer on
  `ubuntu1` runs this. Under ADR-0005 the schedule is host config and belongs in
  `ansible-homelab` as a systemd timer.
- **No build alerting.** Wrap `build.sh` in Cronitor, matching the pattern already used
  by the vmnas 3-2-1 pushes.
- **Consider key-based auth for the build user**, removing password auth from the
  installer entirely.
- **Stale branches.** This repo now works trunk-based on `main`. `develop` is 25 commits
  behind and unused, and `feature/ansible-setup` is fully merged; both can be deleted
  locally and on the remote.
