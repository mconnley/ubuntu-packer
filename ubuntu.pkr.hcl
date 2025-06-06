packer {
  required_version = ">= 1.10.0"
  required_plugins {
    name = {
      version = "~> 1"
      source  = "github.com/hashicorp/proxmox"
    }
  }
}


//////////////////////////////////////////////////////////////////////////////////
// LOCALS
//////////////////////////////////////////////////////////////////////////////////

locals {
  buildtime = formatdate("YYYY-MM-DD hh:mm ZZZ", timestamp())
}

//////////////////////////////////////////////////////////////////////////////////
// SOURCES
//////////////////////////////////////////////////////////////////////////////////

source "proxmox-iso" "ubuntu-noble" {
  //General Builder Options

  //ISO Configuration
  boot_iso {
    iso_url = var.iso_url_noble
    iso_checksum = var.iso_checksum_noble
    unmount = true
    iso_storage_pool = var.iso_storage_pool
  }

  //Boot Options
  boot_wait = var.vm_boot_wait
  boot_command = var.noble_vm_boot_command

  //HTTP Options
  http_directory = var.http_directory
  
  //Proxmox Connection
  proxmox_url = var.proxmox_url
  username = var.proxmox_username
  token = var.proxmox_token
  node = var.proxmox_node
  task_timeout = var.proxmox_task_timeout

  //VM and Template Configuration
  vm_name = var.noble_vm_name
  template_description = "Ubuntu Noble Template - ${local.buildtime}"
  template_name = var.noble_vm_name
  os = var.vm_os
  cloud_init = true
  cloud_init_storage_pool = var.vm_storage_pool

  //Hardware
  sockets = var.vm_cpu_sockets
  cores = var.vm_cpu_cores
  memory = var.vm_mem_size
  scsi_controller = var.vm_scsi_controller
  network_adapters {
    model = var.vm_network_model
    bridge = var.vm_network_bridge

  }

  disks {
    disk_size = var.vm_disk_size
    storage_pool = var.vm_storage_pool
    type = var.vm_disk_type
    discard = var.vm_disk_discard
    //format = var.vm_disk_format
    io_thread = var.vm_disk_iothread
    ssd = var.vm_disk_ssd
  }

  //SSH Configuration
  ssh_password = var.ssh_password
  ssh_username = var.ssh_username
  ssh_port = 22
  ssh_timeout = var.ssh_timeout
  ssh_handshake_attempts = "100000"
}

//////////////////////////////////////////////////////////////////////////////////
// BUILD
//////////////////////////////////////////////////////////////////////////////////

build {
  name = "generic"
  sources = [
    "proxmox-iso.ubuntu-noble"
    ]
  provisioner "file" {
    source = "files/postbuild_job.sh"
    destination = "/tmp/postbuild_job.sh"
  }
  provisioner "shell" {
    inline = [
      "sed -i 's/REPLACE_FQDN/${var.check_mk_fqdn}/' /tmp/postbuild_job.sh",
      "sed -i 's/REPLACE_SITE/${var.check_mk_site}/' /tmp/postbuild_job.sh",
      "sed -i 's/REPLACE_USERNAME/${var.check_mk_username}/' /tmp/postbuild_job.sh",
      "sed -i 's/REPLACE_PASSWORD/${var.check_mk_password}/' /tmp/postbuild_job.sh"
    ]
  }
  provisioner "file" {
    source = "files/99-disable-network-config.cfg"
    destination = "/tmp/99-disable-network-config.cfg"
  }
  provisioner "shell" {
    inline = ["sudo mv /tmp/99-disable-network-config.cfg /etc/cloud/cloud.cfg.d/99-disable-network-config.cfg"]
  }
  provisioner "file" {
    source = "files/secure/homelabrootcert.crt"
    destination = "/tmp/homelabrootcert.crt"
  }
  provisioner "file" {
    source = "files/homelabntp.conf"
    destination = "/tmp/homelabntp.conf"
  }
  provisioner "file" {
    source = "files/multipath.conf"
    destination = "/tmp/multipath.conf"
  }  
  provisioner "shell" {
    inline = [
      "sudo mv /tmp/homelabrootcert.crt /usr/local/share/ca-certificates/homelabroot.crt",
      "sudo update-ca-certificates",
      "echo 'matt:${var.matt_password}' | sudo chpasswd",
      "sudo passwd -u matt"
    ]
  }
  provisioner "shell" {
    execute_command = "echo '${var.ssh_password}' | {{.Vars}} sudo -S -E bash '{{.Path}}'"
    environment_vars = [
      "BUILD_USERNAME=${var.ssh_username}",
    ]
    scripts = var.shell_scripts
    expect_disconnect = true
  }
}