packer {
  required_version = ">= 1.10.0"
  required_plugins {
    vsphere = {
      source  = "github.com/hashicorp/vsphere"
      version = ">= 1.2.4"
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
source "vsphere-iso" "ubuntu-generic" {
  //General Builder Options
  convert_to_template = true
  //Boot Options
  boot_wait = var.vm_boot_wait
  boot_command = var.generic_vm_boot_command
  //HTTP Options
  http_directory = var.http_directory
  //vSphere Connection
  vcenter_server = var.vsphere_endpoint
  username = var.vsphere_username
  password = var.vsphere_password
  insecure_connection = var.vsphere_insecure_connection
  datacenter = var.vsphere_datacenter
  //Hardware
  CPUs = var.vm_cpu_sockets
  cpu_cores = var.vm_cpu_cores
  RAM = var.vm_mem_size
  //Location
  vm_name = var.generic_vm_name
  cluster = var.vsphere_cluster
  datastore = var.vsphere_datastore
  //Shutdown Configuration
  shutdown_command = var.vm_shutdown_command_text
  shutdown_timeout = "15m"
  //Wait Configuration
  //ISO Configuration
  iso_url = var.iso_url
  iso_checksum = var.iso_checksum
  //Create Configuration
  guest_os_type = var.vm_guest_os_type
  vm_version = var.vm_version
  network_adapters {
      network = var.vsphere_network
      network_card = "vmxnet3"
    }
  disk_controller_type = ["pvscsi"]
  storage {
    disk_size = var.vm_disk_size
    disk_thin_provisioned = true
  }
  //Export Configuration
  //SSH Configuration
  ssh_password = var.ssh_password
  ssh_username = var.ssh_username
  ssh_port = 22
  ssh_timeout = var.ssh_timeout
  ssh_handshake_attempts = "100000"
}

source "vsphere-iso" "ubuntu-noble" {
  //General Builder Options
  convert_to_template = true
  //Boot Options
  boot_wait = var.vm_boot_wait
  boot_command = var.noble_vm_boot_command
  //HTTP Options
  http_directory = var.http_directory
  //vSphere Connection
  vcenter_server = var.vsphere_endpoint
  username = var.vsphere_username
  password = var.vsphere_password
  insecure_connection = var.vsphere_insecure_connection
  datacenter = var.vsphere_datacenter
  //Hardware
  CPUs = var.vm_cpu_sockets
  cpu_cores = var.vm_cpu_cores
  RAM = var.vm_mem_size
  //Location
  vm_name = var.noble_vm_name
  cluster = var.vsphere_cluster
  datastore = var.vsphere_datastore
  //Shutdown Configuration
  shutdown_command = var.vm_shutdown_command_text
  shutdown_timeout = "15m"
  //Wait Configuration
  //ISO Configuration
  iso_url = var.iso_url_noble
  iso_checksum = var.iso_checksum_noble
  //Create Configuration
  guest_os_type = var.vm_guest_os_type
  vm_version = var.vm_version
  network_adapters {
      network = var.vsphere_network
      network_card = "vmxnet3"
    }
  disk_controller_type = ["pvscsi"]
  storage {
    disk_size = var.vm_disk_size
    disk_thin_provisioned = true
  }
  //Export Configuration
  //SSH Configuration
  ssh_password = var.ssh_password
  ssh_username = var.ssh_username
  ssh_port = 22
  ssh_timeout = var.ssh_timeout
  ssh_handshake_attempts = "100000"
}

source "vsphere-iso" "ubuntu-rancher" {
  //General Builder Options
  convert_to_template = true
  //Boot Options
  boot_wait = var.vm_boot_wait
  boot_command = var.rancher_vm_boot_command
  //HTTP Options
  http_directory = var.http_directory
  //vSphere Connection
  vcenter_server = var.vsphere_endpoint
  username = var.vsphere_username
  password = var.vsphere_password
  insecure_connection = var.vsphere_insecure_connection
  datacenter = var.vsphere_datacenter
  //Hardware
  CPUs = var.vm_cpu_sockets
  cpu_cores = var.vm_cpu_cores
  RAM = var.vm_mem_size
  //Location
  vm_name = var.rancher_vm_name
  cluster = var.vsphere_cluster
  datastore = var.vsphere_datastore
  //Shutdown Configuration
  shutdown_command = var.vm_shutdown_command_text
  shutdown_timeout = "15m"
  //Wait Configuration
  //ISO Configuration
  iso_url = var.iso_url_noble
  iso_checksum = var.iso_checksum_noble
  //Create Configuration
  guest_os_type = var.vm_guest_os_type
  vm_version = var.vm_version
  network_adapters {
      network = var.vsphere_network
      network_card = "vmxnet3"
    }
  disk_controller_type = ["pvscsi", "pvscsi"]
  storage {
    disk_size = var.vm_disk_size
    disk_thin_provisioned = true
    disk_controller_index = 0
  }
  storage {
    disk_size = var.vm_docker_disk_size
    disk_thin_provisioned = true
    disk_controller_index = 1
  }
  //Export Configuration
  //SSH Configuration
  ssh_password = var.ssh_password
  ssh_username = var.ssh_username
  ssh_port = 22
  ssh_timeout = var.ssh_timeout
  ssh_handshake_attempts = "100000"
}

source "vsphere-iso" "ubuntu-rancherlonghorn" {
  //General Builder Options
  convert_to_template = true
  //Boot Options
  boot_wait = var.vm_boot_wait
  boot_command = var.rancherlonghorn_vm_boot_command
  //HTTP Options
  http_directory = var.http_directory
  //vSphere Connection
  vcenter_server = var.vsphere_endpoint
  username = var.vsphere_username
  password = var.vsphere_password
  insecure_connection = var.vsphere_insecure_connection
  datacenter = var.vsphere_datacenter
  //Hardware
  CPUs = var.vm_cpu_sockets
  cpu_cores = var.vm_cpu_cores
  RAM = var.vm_mem_size
  //Location
  vm_name = var.rancherlonghorn_vm_name
  cluster = var.vsphere_cluster
  datastore = var.vsphere_datastore
  //Shutdown Configuration
  shutdown_command = var.vm_shutdown_command_text
  shutdown_timeout = "15m"
  //Wait Configuration
  //ISO Configuration
  iso_url = var.iso_url
  iso_checksum = var.iso_checksum
  //Create Configuration
  guest_os_type = var.vm_guest_os_type
  vm_version = var.vm_version
  network_adapters {
      network = var.vsphere_network
      network_card = "vmxnet3"
    }
  disk_controller_type = ["pvscsi", "pvscsi", "pvscsi"]
  storage {
    disk_size = var.vm_disk_size
    disk_thin_provisioned = true
    disk_controller_index = 0
  }
  storage {
    disk_size = var.vm_docker_disk_size
    disk_thin_provisioned = true
    disk_controller_index = 1
  }
  storage {
    disk_size = var.vm_longhorn_disk_size
    disk_thin_provisioned = true
    disk_controller_index = 2
  }
  //Export Configuration
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
    "vsphere-iso.ubuntu-noble",
    "vsphere-iso.ubuntu-generic",
    "vsphere-iso.ubuntu-rancher",
    "vsphere-iso.ubuntu-rancherlonghorn",
    "vmware-iso.ubuntu-20-generic"
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
}