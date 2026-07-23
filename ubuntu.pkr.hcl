##################################################################################
# Ubuntu Server -> Proxmox template
#
# ONE source, parameterized by release. Each Ubuntu release is a var file under
# releases/, and build.sh runs this template once per release.
#
# Why not one source per release, or build-block source overrides? Packer's
# build-block overrides can only set top-level attributes, and the ISO lives in
# the nested `boot_iso` block — so a per-release ISO cannot be expressed that
# way. Parameterizing a single source keeps the duplication at zero.
#
# Adding a release: drop a new file in releases/ and add its codename to the
# RELEASES list in build.sh. Nothing here should need to change.
##################################################################################

packer {
  required_version = ">= 1.10.0"
  required_plugins {
    proxmox = {
      version = "~> 1.2"
      source  = "github.com/hashicorp/proxmox"
    }
  }
}

##################################################################################
# LOCALS
##################################################################################

locals {
  buildtime = formatdate("YYYY-MM-DD hh:mm ZZZ", timestamp())

  # Throwaway password for the build user, regenerated every run and never
  # written anywhere persistent. The account exists only between the installer
  # creating it and vm_shutdown_command deleting it, so there is nothing worth
  # storing — and nothing to keep in sync with a committed hash.
  packer_password = uuidv4()

  # The autoinstall config is rendered here and served from Packer's built-in
  # HTTP server (see http_content below), never written to disk. That is what
  # keeps credentials out of the tracked tree.
  user_data = templatefile("${path.root}/http/user-data.pkrtpl.hcl", {
    packer_username      = var.ssh_username
    packer_password      = local.packer_password
    debug_authorized_key = var.debug_authorized_key
    matt_ssh_key         = var.matt_ssh_key
    ansible_ssh_key      = var.ansible_ssh_key
    locale               = var.locale
    keyboard_layout      = var.keyboard_layout
    apt_fallback_mirror  = var.apt_fallback_mirror
    packages             = var.autoinstall_packages
    nfs_mounts           = var.nfs_mounts
  })
}

##################################################################################
# SOURCE
##################################################################################

source "proxmox-iso" "ubuntu" {

  # --- Installer media -----------------------------------------------------
  boot_iso {
    iso_url          = var.iso_url
    iso_checksum     = var.iso_checksum
    iso_storage_pool = var.iso_storage_pool
    unmount          = true
  }

  # --- Autoinstall seed ----------------------------------------------------
  # http_content serves generated content at these paths; the boot command
  # points cloud-init's nocloud-net datasource at the server root.
  http_content = {
    "/meta-data" = ""
    "/user-data" = local.user_data
  }

  boot_wait    = var.vm_boot_wait
  boot_command = var.vm_boot_command

  # --- Proxmox connection --------------------------------------------------
  proxmox_url  = var.proxmox_url
  username     = var.proxmox_username
  token        = var.proxmox_token
  node         = var.proxmox_node
  task_timeout = var.proxmox_task_timeout

  # --- VM and template identity --------------------------------------------
  vm_id                   = var.vm_id
  vm_name                 = var.vm_name
  template_name           = var.vm_name
  template_description    = "Ubuntu ${var.release_version} (${var.release_codename}) — built ${local.buildtime} by ubuntu-packer"
  os                      = var.vm_os
  cloud_init              = true
  cloud_init_storage_pool = var.vm_storage_pool

  # --- Hardware ------------------------------------------------------------
  sockets         = var.vm_cpu_sockets
  cores           = var.vm_cpu_cores
  memory          = var.vm_mem_size
  scsi_controller = var.vm_scsi_controller

  network_adapters {
    model  = var.vm_network_model
    bridge = var.vm_network_bridge
  }

  disks {
    disk_size    = var.vm_disk_size
    storage_pool = var.vm_storage_pool
    type         = var.vm_disk_type
    discard      = var.vm_disk_discard
    io_thread    = var.vm_disk_iothread
    ssd          = var.vm_disk_ssd
  }

  # --- SSH -----------------------------------------------------------------
  ssh_username           = var.ssh_username
  ssh_password           = local.packer_password
  ssh_port               = 22
  ssh_timeout            = var.ssh_timeout
  ssh_handshake_attempts = 100

  # NOTE: this builder has no shutdown_command hook — it powers the VM down
  # through the Proxmox API. The build user is therefore removed at the end of
  # setup_ubuntu.sh (see its SEAL section), which is the last code that runs
  # inside the guest.
}

##################################################################################
# BUILD
##################################################################################

build {
  name    = "generic"
  sources = ["proxmox-iso.ubuntu"]

  # Stage every file the provisioner needs in one step. /tmp is used because the
  # build user cannot write elsewhere before privilege escalation; setup_ubuntu.sh
  # moves each file into place.
  provisioner "file" {
    sources = [
      "${path.root}/files/secure/homelabrootcert.crt",
      "${path.root}/files/homelabntp.conf",
      "${path.root}/files/multipath.conf",
      "${path.root}/files/postbuild_job.sh",
    ]
    destination = "/tmp/"
  }

  # A single provisioning script, run as root.
  #
  # execute_command deliberately avoids `sudo -E`: Ubuntu 26.04 ships sudo-rs as
  # the default sudo, which does not support -E/--preserve-env
  # (trifectatechfoundation/sudo-rs#1299, still open). `sudo env {{.Vars}}` is
  # equivalent and works on every release. No -S / piped password is needed
  # either — the build user has passwordless sudo.
  provisioner "shell" {
    execute_command = "sudo env {{.Vars}} bash '{{.Path}}'"
    environment_vars = [
      "BUILD_USER=${var.ssh_username}",
      "TIMEZONE=${var.timezone}",
      "CHECK_MK_FQDN=${var.check_mk_fqdn}",
      "CHECK_MK_SITE=${var.check_mk_site}",
      "CHECK_MK_USERNAME=${var.check_mk_username}",
      "CHECK_MK_PASSWORD=${var.check_mk_password}",
      "CHECK_MK_AGENT_VERSION=${var.check_mk_agent_version}",
    ]
    scripts           = var.shell_scripts
    expect_disconnect = true
  }
}
