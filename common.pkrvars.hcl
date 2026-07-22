##################################################################################
# COMMON VARIABLES — shared by every Ubuntu release.
#
# Anything that differs between releases belongs in releases/<codename>.pkrvars.hcl.
# Anything secret belongs in sensitive.pkrvars.hcl (untracked).
##################################################################################

##################################################################################
# VM hardware — sizes the BUILD vm only; clones are resized at deploy time.
##################################################################################

vm_cpu_sockets     = 2
vm_cpu_cores       = 1
vm_mem_size        = 2048
vm_disk_size       = "4G"
vm_scsi_controller = "virtio-scsi-single"
vm_disk_type       = "virtio"
vm_disk_iothread   = true
vm_disk_discard    = true
vm_disk_ssd        = false

##################################################################################
# Boot
##################################################################################

vm_boot_wait = "8s"

# Typed at the ISO's GRUB prompt. `c` drops to the GRUB shell so the kernel can
# be booted directly with an `autoinstall` command line — the ISO's stock menu
# entries do not carry one.
#
# The ip= argument is the kernel's static network config, in the order:
#   client::gateway:netmask:hostname:device:autoconf:dns0:dns1:ntp
#   192.168.2.233 :: 192.168.2.1 : 255.255.255.0 :::: 192.168.2.33 : 192.168.2.34 : 192.168.2.1
#
# It is static rather than DHCP so the installer never depends on a lease to
# fetch its seed. Consequence: this address is held for the length of a build,
# so builds MUST be sequential — build.sh runs them in a loop for this reason.
vm_boot_command = [
  "c<wait3s>",
  "linux /casper/vmlinuz ip=192.168.2.233::192.168.2.1:255.255.255.0::::192.168.2.33:192.168.2.34:192.168.2.1 --- autoinstall ipv6.disable=1 ds=\"nocloud-net;seedfrom=http://{{.HTTPIP}}:{{.HTTPPort}}/\"",
  "<enter><wait3s>",
  "initrd /casper/initrd",
  "<enter><wait3s>",
  "boot",
  "<enter>"
]

##################################################################################
# SSH
##################################################################################

ssh_username = "packer"
ssh_timeout  = "90m"

##################################################################################
# Autoinstall content
##################################################################################

locale          = "en_US"
keyboard_layout = "us"
timezone        = "America/Chicago"

# Fallback only — the installer geolocates a country mirror first.
apt_fallback_mirror = "http://archive.ubuntu.com/ubuntu"

autoinstall_packages = [
  "qemu-guest-agent",
  "net-tools",
  "unzip",
  "nfs-common",
  "duf",
]

nfs_mounts = [
  { source = "192.168.2.98:/MCRoot", target = "/nas/MCRoot" },
  { source = "192.168.2.98:/nfsbackup", target = "/nas/nfsbackup" },
]

##################################################################################
# Identity
#
# Public keys only, and public keys are not secrets. No account password exists
# anywhere in this repo — see the identity section of variables.pkr.hcl.
##################################################################################

matt_ssh_key    = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQDI6FIMmDIzZJiZkf5QKrOcfDSaTCTG0UDP795Cee8joCsPhEzxzcn7bsaObWaP4nQMFW2n/ZcMRlkDAd+h0zjxYzHbY4kVxfwBoWkYtmVAvVsbaheKI5QiclA0zHLa7xYtnERlRuuehdvGu5fhjJcVkFg36YyBvbkVJCbpiL8xsPEU6pgU7FL91OW8/ScZjKqzIDt/CiAAia+HfZ2rNSfJN++foMOvTDv0DOzMzbOmM3sui3N3chBXeqzqonUNMB2fDHC2CKxqnEI0oabDaViYi9UffVE1JKhkuvgFq0IBc76AoU1m8Ar7J9XAHYOmBRFk8/g41Q27kTPNaTZULD2Z matt.connley@mcmacbookpro.mattconnley.com"
ansible_ssh_key = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAINKrPIcpcC5y+TECqMeDzdW+45PO/Ddw+/TQzheQD+bN ansible-homelab"

##################################################################################
# Checkmk
#
# Pinned deliberately. Bump in the same change that upgrades the Checkmk server.
##################################################################################

check_mk_agent_version = "2.4.0p17-1"

##################################################################################
# Provisioning
##################################################################################

shell_scripts = ["./scripts/setup_ubuntu.sh"]
