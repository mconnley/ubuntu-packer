variable "ssh_username" {
  type    = string
  description = "The username to use to authenticate over SSH."
  default = ""
  sensitive = true
}

variable "ssh_password" {
  type    = string
  description = "The plaintext password to use to authenticate over SSH."
  default = ""
  sensitive = true
}

variable "matt_password" {
  type    = string
  description = "The plaintext password to use to authenticate user matt over SSH."
  default = ""
  sensitive = true
}

variable "check_mk_fqdn" {
  type    = string
  description = "The fqdn of the checkmk server."
  default = ""
  sensitive = true
}

variable "check_mk_site" {
  type    = string
  description = "The checkmk site to join."
  default = ""
  sensitive = true
}

variable "check_mk_username" {
  type    = string
  description = "The username to authenticate to checkmk"
  default = ""
  sensitive = true
}

variable "check_mk_password" {
  type    = string
  description = "The password to authenticate to checkmk"
  default = ""
  sensitive = true
}

# ISO Objects

variable "iso_path" {
  type    = string
  description = "The path on the source vSphere datastore for ISO images."
  default = ""
  }

variable iso_file{
  type = string
  description = "The file name of the guest operating system ISO image installation media."
  default = ""
}

variable iso_url{
  type = string
  description = "the url to get the ISO from"
  default = ""
}

variable "iso_checksum" {
  type    = string
  description = "The SHA-512 checkcum of the ISO image."
  default = ""
}

# HTTP Endpoint

variable "http_directory" {
  type    = string
  description = "Directory of config files(user-data, meta-data)."
  default = ""
}

# Virtual Machine Settings

variable "vm_guest_os_family" {
  type    = string
  description = "The guest operating system family."
  default = ""
}

variable "generic_vm_name" {
  type    = string
  description = "The VM name for the generic build."
  default = ""
}

variable "rancher_vm_name" {
  type    = string
  description = "The VM name for the Rancher build."
  default = ""
}

variable "rancherlonghorn_vm_name" {
  type    = string
  description = "The VM name for the Rancher+Longhorn build."
  default = ""
}

variable "vm_guest_os_vendor" {
  type    = string
  description = "The guest operating system vendor."
  default = ""
}

variable "vm_guest_os_member" {
  type    = string
  description = "The guest operating system member."
  default = ""
}

variable "vm_guest_os_version" {
  type    = string
  description = "The guest operating system version."
  default = ""
}

variable "vm_guest_os_type" {
  type    = string
  description = "The guest operating system type, also know as guestid."
  default = ""
}

variable vm_version {
  type = number
  description = "The VM virtual hardware version."
  # https://kb.vmware.com/s/article/1003746
}

variable "vm_firmware" {
  type    = string
  description = "The virtual machine firmware. (e.g. 'bios' or 'efi')"
  default = ""
}

variable "vm_cdrom_type" {
  type    = string
  description = "The virtual machine CD-ROM type."
  default = ""
}

variable "vm_cpu_sockets" {
  type = number
  description = "The number of virtual CPUs sockets."
}

variable "vm_cpu_cores" {
  type = number
  description = "The number of virtual CPUs cores per socket."
}

variable "vm_mem_size" {
  type = number
  description = "The size for the virtual memory in MB."
}

variable "vm_disk_size" {
  type = number
  description = "The size for the main disk in MB."
}

variable "vm_docker_disk_size" {
  type = number
  description = "The size for the Docker disk in MB."
  default = 32768
}

variable "vm_longhorn_disk_size" {
  type = number
  description = "The size for the Docker disk in MB."
  default = 32768
}

variable "vm_disk_controller_type" {
  type = list(string)
  description = "The virtual disk controller types in sequence."
}

variable "vm_network_card" {
  type = string
  description = "The virtual network card type."
  default = ""
}

variable "vm_boot_wait" {
  type = string
  description = "The time to wait before boot. "
  default = ""
}

variable "shell_scripts" {
  type = list(string)
  description = "A list of scripts."
  default = []
}

variable "generic_vm_boot_command" {
  type = list(string)
  description = "A list of boot commands."
  default = []
}

variable "rancher_vm_boot_command" {
  type = list(string)
  description = "A list of boot commands."
  default = []
}

variable "rancherlonghorn_vm_boot_command" {
  type = list(string)
  description = "A list of boot commands."
  default = []
}

variable "vm_shutdown_command_text" {
  type = string
  description = "The string of commands issued to shut down the VM after successful build."
  default = ""
}

##################################################################################
# LOCALS
##################################################################################

locals {
  buildtime = formatdate("YYYY-MM-DD hh:mm ZZZ", timestamp())
}

##################################################################################
# SOURCES
##################################################################################
source "vmware-iso" "ubuntu-generic" {
  guest_os_type = var.vm_guest_os_type
  vm_name = var.generic_vm_name
  cpus = var.vm_cpu_sockets
  cores = var.vm_cpu_cores
  memory = var.vm_mem_size
  disk_adapter_type = "pvscsi"
  disk_size = var.vm_disk_size
  disk_type_id = 0
  network_adapter_type = "vmxnet3"
  network = "NAT"
  iso_url = var.iso_url
  iso_checksum = var.iso_checksum
  http_directory = var.http_directory
  boot_wait = var.vm_boot_wait
  boot_command = var.generic_vm_boot_command
  ssh_password = var.ssh_password
  ssh_username = var.ssh_username
  ssh_port = 22
  ssh_timeout = "30m"
  ssh_handshake_attempts = "100000"
  shutdown_command = var.vm_shutdown_command_text
  shutdown_timeout = "15m"
  output_directory = "x:\\packer_builds\\ubuntu-generic"
  format = "ova"  
  vmx_data = { 
    "vmx.scoreboard.enabled" = "FALSE" 
    "virtualhw.version" = "19"
    }
  ovftool_options = ["-dm=thin", "--maxVirtualHardwareVersion=19" ]
}

source "vmware-iso" "ubuntu-rancher" {
  guest_os_type = var.vm_guest_os_type
  vm_name = var.rancher_vm_name
  cpus = var.vm_cpu_sockets
  cores = var.vm_cpu_cores
  memory = var.vm_mem_size
  disk_adapter_type = "pvscsi"
  disk_size = var.vm_disk_size
  disk_additional_size = [var.vm_docker_disk_size]
  disk_type_id = 0
  network_adapter_type = "vmxnet3"
  network = "NAT"
  iso_url = var.iso_url
  iso_checksum = var.iso_checksum
  http_directory = var.http_directory
  boot_wait = var.vm_boot_wait
  boot_command = var.rancher_vm_boot_command
  ssh_password = var.ssh_password
  ssh_username = var.ssh_username
  ssh_port = 22
  ssh_timeout = "30m"
  ssh_handshake_attempts = "100000"
  shutdown_command = var.vm_shutdown_command_text
  shutdown_timeout = "15m"
  output_directory = "x:\\packer_builds\\ubuntu-rancher"
  format = "ova"
  vmx_data = { 
    "vmx.scoreboard.enabled" = "FALSE" 
    "virtualhw.version" = "19"
    }
  ovftool_options = ["-dm=thin", "--maxVirtualHardwareVersion=19" ]
}

source "vmware-iso" "ubuntu-rancherlonghorn" {
  guest_os_type = var.vm_guest_os_type
  vm_name = var.rancherlonghorn_vm_name
  cpus = var.vm_cpu_sockets
  cores = var.vm_cpu_cores
  memory = var.vm_mem_size
  disk_adapter_type = "pvscsi"
  disk_size = var.vm_disk_size
  disk_additional_size = [var.vm_docker_disk_size, var.vm_longhorn_disk_size]
  disk_type_id = 0
  network_adapter_type = "vmxnet3"
  network = "NAT"
  iso_url = var.iso_url
  iso_checksum = var.iso_checksum
  http_directory = var.http_directory
  boot_wait = var.vm_boot_wait
  boot_command = var.rancherlonghorn_vm_boot_command
  ssh_password = var.ssh_password
  ssh_username = var.ssh_username
  ssh_port = 22
  ssh_timeout = "30m"
  ssh_handshake_attempts = "100000"
  shutdown_command = var.vm_shutdown_command_text
  shutdown_timeout = "15m"
  output_directory = "x:\\packer_builds\\ubuntu-rancherlonghorn"
  format = "ova"
  vmx_data = { 
    "vmx.scoreboard.enabled" = "FALSE" 
    "virtualhw.version" = "19"
    }
  ovftool_options = ["-dm=thin", "--maxVirtualHardwareVersion=19" ]
}

##################################################################################
# BUILD
##################################################################################

build {
  name = "generic"
  sources = [
    "vmware-iso.ubuntu-generic",
    "vmware-iso.ubuntu-rancher",
    "vmware-iso.ubuntu-rancherlonghorn"
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
  provisioner "shell" {
    execute_command = "echo '${var.ssh_password}' | {{.Vars}} sudo -S -E bash '{{.Path}}'"
    environment_vars = [
      "BUILD_USERNAME=${var.ssh_username}",
    ]
    scripts = var.shell_scripts
    expect_disconnect = true
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
  provisioner "shell" {
    inline = [
      "sudo mv /tmp/homelabrootcert.crt /usr/local/share/ca-certificates/homelabroot.crt",
      "sudo update-ca-certificates",
      "echo 'matt:${var.matt_password}' | sudo chpasswd",
      "sudo passwd -u matt"
    ]
  }
}