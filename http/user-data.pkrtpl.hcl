#cloud-config
##################################################################################
# Ubuntu Server autoinstall — shared by every release.
#
# Rendered by templatefile() in ubuntu.pkr.hcl and served from Packer's built-in
# HTTP server. It is never written to disk, which is why credentials may appear
# here but must never appear in a tracked file.
#
# Schema is subiquity `version: 1`. Keep it that way: from 24.04 onward,
# unrecognized keys are a warning under version 1 but a FATAL validation error
# under later schema versions. Do not add speculative keys.
##################################################################################
autoinstall:
  version: 1

  # Stop the installer's own sshd so Packer cannot connect to the live
  # environment and mistake it for the installed system.
  early-commands:
    - systemctl stop ssh

  locale: ${locale}
  keyboard:
    layout: ${keyboard_layout}

  ssh:
    install-server: true
    # Required only for the duration of the build: Packer authenticates the
    # build user by password. setup_ubuntu.sh turns this back off before the
    # template is sealed.
    allow-pw: true

  # Pull from -security AND -updates during installation, not just -security
  # (the default). This repo exists to produce a template that is current the
  # moment it is cloned; this is that goal in one line.
  updates: all

  apt:
    # mirror-selection supersedes the legacy flat `primary:` list. country-mirror
    # lets the installer geolocate, with the global archive as fallback — which
    # is also the guard against a stale hand-pinned foreign mirror.
    mirror-selection:
      primary:
        - country-mirror
        - uri: "${apt_fallback_mirror}"

  # Legacy BIOS layout: a 1 MiB bios_grub partition plus a single XFS root.
  # Deliberately matched across releases so a release upgrade does not also
  # change the firmware path. Moving to UEFI is a separate, explicit migration.
  storage:
    config:
      - {
          ptable: gpt,
          path: /dev/vda,
          wipe: superblock-recursive,
          preserve: false,
          name: "",
          grub_device: true,
          type: disk,
          id: disk-vda,
        }
      - {
          device: disk-vda,
          size: 1048576,
          flag: bios_grub,
          number: 1,
          preserve: false,
          grub_device: false,
          type: partition,
          id: partition-0,
        }
      - {
          device: disk-vda,
          size: -1,
          wipe: superblock,
          flag: "",
          number: 2,
          preserve: false,
          grub_device: false,
          type: partition,
          id: partition-1,
        }
      - {
          fstype: xfs,
          volume: partition-1,
          preserve: false,
          type: format,
          id: format-0,
        }
      - { path: /, device: format-0, type: mount, id: mount-0 }

  packages:
%{ for pkg in packages ~}
    - ${pkg}
%{ endfor ~}

%{ if length(nfs_mounts) > 0 ~}
  # nofail + _netdev: an unreachable NAS must never block boot.
  mounts:
%{ for m in nfs_mounts ~}
    - [ "${m.source}", "${m.target}", "nfs", "defaults,nofail,_netdev", "0", "0" ]
%{ endfor ~}
%{ endif ~}

  user-data:
    disable_root: true
    users:
      # Build user. Ephemeral in every sense: the password is regenerated per
      # build, and the account is deleted in the SEAL section of setup_ubuntu.sh
      # before the template is sealed. Nothing about it persists into a clone.
      #
      # debug_authorized_key, when set, authorizes an operator key on THIS
      # account only, so a build that fails during provisioning can be logged
      # into for diagnosis (the per-run password is otherwise unrecoverable).
      # Empty in normal builds, so nothing is baked in; and even when set it dies
      # with the account at seal time. See the "Debugging a failed build" section
      # of the README.
      - name: ${packer_username}
        plain_text_passwd: "${packer_password}"
        lock_passwd: false
        sudo: ALL=(ALL) NOPASSWD:ALL
%{ if debug_authorized_key != "" ~}
        ssh_authorized_keys:
          - ${debug_authorized_key}
%{ endif ~}

      # Key-only, like the ansible user. No password is set here at all: the
      # console password is Ansible's to manage from OpenBao (configure_users),
      # where it can actually be rotated — the image is the wrong place for a
      # credential with an indefinite lifetime.
      #
      # Trade-off: until Ansible has run, this account cannot log in at the
      # Proxmox console, only over SSH. See README.
      - name: matt
        lock_passwd: true
        sudo: ALL=(ALL) NOPASSWD:ALL
        ssh_authorized_keys:
          - ${matt_ssh_key}

      # The handoff to ansible-homelab. This key is the reason the account is
      # baked into the image rather than configured later — Ansible cannot
      # reach the host to create its own way in.
      - name: ansible
        lock_passwd: true
        sudo: ALL=(ALL) NOPASSWD:ALL
        ssh_authorized_keys:
          - ${ansible_ssh_key}

    chpasswd:
      expire: false

  late-commands:
    # Password auth for the build user only; reverted before sealing.
    - sed -i -e 's/^#\?PasswordAuthentication.*/PasswordAuthentication yes/g' /target/etc/ssh/sshd_config
    - echo '${packer_username} ALL=(ALL) NOPASSWD:ALL' > /target/etc/sudoers.d/${packer_username}
    - curtin in-target --target=/target -- chmod 440 /etc/sudoers.d/${packer_username}
