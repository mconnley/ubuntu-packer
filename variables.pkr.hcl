##################################################################################
# VARIABLES
#
# Values are supplied by three var files, layered in this order (see build.sh):
#
#   common.pkrvars.hcl                shared across every release  (tracked)
#   releases/<codename>.pkrvars.hcl   one per Ubuntu release       (tracked)
#   sensitive.pkrvars.hcl             credentials                  (NOT tracked)
#
# Anything marked `sensitive = true` is redacted from Packer's output and must
# live only in sensitive.pkrvars.hcl. See sensitive.pkrvars.hcl.example.
#
# Note the deliberate absence of `default = ""` on required values: an empty
# default turns a missing credential into a confusing mid-build failure, whereas
# no default fails immediately with the variable's name.
##################################################################################

##################################################################################
# Proxmox connection
##################################################################################

variable "proxmox_url" {
  type        = string
  description = "Proxmox API endpoint, e.g. https://pvehost1.example.com:8006/api2/json"
  sensitive   = true
}

variable "proxmox_username" {
  type        = string
  description = "Proxmox API token owner, in the form user@realm!tokenid."
  sensitive   = true
}

variable "proxmox_token" {
  type        = string
  description = "Proxmox API token secret (GUID)."
  sensitive   = true
}

variable "proxmox_node" {
  type        = string
  description = "Proxmox node that runs the build."
}

variable "proxmox_task_timeout" {
  type        = string
  description = "How long to wait on a single Proxmox task before giving up."
  default     = "30m"
}

variable "iso_storage_pool" {
  type        = string
  description = "Proxmox storage pool the installer ISO is downloaded to."
  default     = "local"
}

variable "vm_storage_pool" {
  type        = string
  description = "Proxmox storage pool for the VM disk and the cloud-init drive."
  default     = "local-lvm"
}

##################################################################################
# Release-specific — set in releases/<codename>.pkrvars.hcl
##################################################################################

variable "release_codename" {
  type        = string
  description = "Ubuntu release codename, e.g. noble or resolute. Used in naming only."
}

variable "release_version" {
  type        = string
  description = "Ubuntu release version, e.g. 24.04 or 26.04. Used in the template description."
}

variable "iso_url" {
  type        = string
  description = <<-EOT
    Full URL of the live-server ISO.

    Consumed by build.sh's ensure_iso, NOT by this template — the ISO is
    pre-staged in the pool server-side and Packer boots it via iso_file. The
    filename carries the LTS point release (24.04.4, 26.04.1, ...), and
    releases.ubuntu.com removes superseded point releases, so this needs a bump
    roughly twice a year. When it does, iso_filename changes too, the pool cache
    misses, and the new ISO is pulled automatically.
  EOT
}

variable "iso_checksum" {
  type        = string
  description = <<-EOT
    `file:` URL of the release's SHA256SUMS. Consumed by build.sh's ensure_iso,
    which looks up the sha256 for iso_filename and hands it to Proxmox's
    server-side download so integrity is verified at download time:

      file:https://releases.ubuntu.com/24.04/SHA256SUMS
  EOT
}

variable "iso_filename" {
  type        = string
  description = <<-EOT
    Stable basename the ISO is stored under in the pool, e.g.
    ubuntu-26.04-live-server-amd64.iso. Packer boots it via
    iso_file = "<iso_storage_pool>:iso/<iso_filename>". Keep it equal to the ISO
    URL's basename: that is what makes the pool cache hit on an unchanged release
    and miss (re-download) on a point-release bump.
  EOT
}

variable "template_name" {
  type        = string
  description = "Canonical template name clones select by, e.g. ubuntu-noble-template. The build is named <template_name>-building and renamed to this on success."
}

variable "build_vm_id" {
  type        = number
  description = <<-EOT
    The DISPOSABLE vmid to build into THIS run — one of the release's two slots
    (build_vm_id_a / build_vm_id_b), chosen by build.sh as whichever does not
    currently hold the canonical template, and passed in with -var. Built with
    -force. Never the slot holding the live template, so a failed build cannot
    harm it.
  EOT
}

variable "build_vm_id_a" {
  type        = number
  description = "First of two disposable build slots for this release. Read by build.sh (not the template) to pick build_vm_id; the two slots alternate (blue/green) across nightly builds."
}

variable "build_vm_id_b" {
  type        = number
  description = "Second disposable build slot. See build_vm_id_a."
}

##################################################################################
# VM hardware
#
# These size the *build* VM, not the clones — clones are resized at deploy time.
##################################################################################

variable "vm_os" {
  type        = string
  description = "Proxmox guest OS type. l26 = Linux 2.6+ kernel."
  default     = "l26"
}

variable "vm_cpu_sockets" {
  type        = number
  description = "Virtual CPU sockets."
}

variable "vm_cpu_cores" {
  type        = number
  description = "Virtual CPU cores per socket."
}

variable "vm_mem_size" {
  type        = number
  description = "Memory in MB."
}

variable "vm_disk_size" {
  type        = string
  description = "Disk size with a unit suffix, e.g. 4G."
}

variable "vm_scsi_controller" {
  type        = string
  description = "SCSI controller model. virtio-scsi-single is required for io_thread."
  default     = "virtio-scsi-single"
}

variable "vm_disk_type" {
  type        = string
  description = "Disk bus/type, e.g. virtio or scsi."
  default     = "virtio"
}

variable "vm_disk_discard" {
  type        = bool
  description = <<-EOT
    Pass guest TRIM/UNMAP through to the storage layer. Keep this true on
    thin-provisioned backends — with it off, blocks freed inside the guest are
    never returned and the pool grows monotonically.
  EOT
  default     = true
}

variable "vm_disk_iothread" {
  type        = bool
  description = "Give the disk its own I/O thread. Requires virtio-scsi-single."
  default     = true
}

variable "vm_disk_ssd" {
  type        = bool
  description = "Advertise the disk to the guest as an SSD (sets rotational=0)."
  default     = false
}

variable "vm_network_model" {
  type        = string
  description = "Virtual NIC model."
  default     = "virtio"
}

variable "vm_network_bridge" {
  type        = string
  description = "Proxmox bridge the build VM attaches to."
  default     = "vmbr0"
}

##################################################################################
# Boot and SSH
##################################################################################

variable "vm_boot_wait" {
  type        = string
  description = "How long to wait at the GRUB prompt before typing boot_command."
  default     = "8s"
}

variable "vm_boot_command" {
  type        = list(string)
  description = <<-EOT
    Keystrokes typed at the ISO's GRUB prompt to start an autoinstall.

    Drops to the GRUB shell (`c`) and boots /casper/vmlinuz directly so the
    kernel command line can carry `autoinstall` and the nocloud-net seed URL —
    the ISO's own menu entries include neither. These paths are unchanged
    through 26.04.

    Contains a *static* build-time IP; see common.pkrvars.hcl for the breakdown
    and the constraint it implies (builds must not run concurrently).
  EOT
}

variable "ssh_username" {
  type        = string
  description = <<-EOT
    Build user Packer connects as. Created by the autoinstall with passwordless
    sudo, and deleted again in the SEAL section of setup_ubuntu.sh — this builder
    has no shutdown_command hook, so that script is the last chance to remove it.
  EOT
  default     = "packer"
}

variable "ssh_timeout" {
  type        = string
  description = "How long to wait for SSH after boot. Must exceed a full unattended install."
  default     = "90m"
}

variable "debug_authorized_key" {
  type        = string
  description = <<-EOT
    Operator public SSH key, authorized on the build user for diagnosis only.

    Empty in every normal build. When set (via -var or a local var file, NOT
    committed), and paired with `PACKER_ON_ERROR=ask`, a build that fails during
    the provisioning phase stays up and is reachable as the build user — which
    is otherwise impossible, since its password is a per-run uuid that is never
    stored. Only helps AFTER first boot: an installer-phase failure has no
    installed system to reach. See the README.
  EOT
  default     = ""
}

##################################################################################
# Autoinstall — identity
#
# No account password appears here, by design:
#
#   * the build user's password is generated per run (see locals in
#     ubuntu.pkr.hcl) and the account is deleted before the template is sealed;
#   * matt and ansible are key-only in the image. matt's console password is
#     set post-boot by ansible-homelab's configure_users role from OpenBao,
#     where it can be rotated — an image is the wrong place to store a
#     credential with an indefinite lifetime.
#
# Public keys are not secrets and live in common.pkrvars.hcl.
##################################################################################

variable "matt_ssh_key" {
  type        = string
  description = "Public SSH key authorized for the matt user. Public keys are not secret."
}

variable "ansible_ssh_key" {
  type        = string
  description = <<-EOT
    Public SSH key authorized for the ansible user — the handoff point to the
    ansible-homelab repo. This must be baked in: it is what lets Ansible reach
    the host at all. See ADR-0005 in the homelab-gitops repo.
  EOT
}

##################################################################################
# Autoinstall — content
##################################################################################

variable "locale" {
  type        = string
  description = "System locale."
  default     = "en_US"
}

variable "keyboard_layout" {
  type        = string
  description = "Console keyboard layout."
  default     = "us"
}

variable "apt_fallback_mirror" {
  type        = string
  description = <<-EOT
    Mirror used if the installer's geolocated country-mirror is unreachable.
    Leave this as the global archive; do not pin a foreign country mirror here.
  EOT
  default     = "http://archive.ubuntu.com/ubuntu"
}

variable "autoinstall_packages" {
  type        = list(string)
  description = "Packages installed by the installer itself, before first boot."
}

variable "nfs_mounts" {
  type = list(object({
    source = string
    target = string
  }))
  description = "NFS mounts written to /etc/fstab, mounted nofail so a dead NAS cannot block boot."
  default     = []
}

variable "timezone" {
  type        = string
  description = "System timezone applied during provisioning."
  default     = "America/Chicago"
}

##################################################################################
# Checkmk
#
# The agent package is installed into the image. Registration with the Checkmk
# server is a separate, host-specific concern — see files/postbuild_job.sh and
# the open question in README.md.
##################################################################################

variable "check_mk_fqdn" {
  type        = string
  description = "Checkmk server FQDN."
  sensitive   = true
}

variable "check_mk_site" {
  type        = string
  description = "Checkmk site name."
  sensitive   = true
}

variable "check_mk_username" {
  type        = string
  description = "Checkmk automation user."
  sensitive   = true
}

variable "check_mk_password" {
  type        = string
  description = "Checkmk automation secret."
  sensitive   = true
}

variable "check_mk_agent_version" {
  type        = string
  description = <<-EOT
    Agent package version, pinned deliberately rather than tracking the server.
    Bump this in the same change that upgrades the Checkmk server, so the image
    and the server never drift silently.
  EOT
}

##################################################################################
# Provisioning
##################################################################################

variable "shell_scripts" {
  type        = list(string)
  description = "Provisioning scripts run, in order, as root."
  default     = ["./scripts/setup_ubuntu.sh"]
}
