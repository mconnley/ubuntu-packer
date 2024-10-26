variable "ssh_username" {
  type        = string
  description = "The username to use to authenticate over SSH."
  default     = ""
  sensitive   = true
}

variable "ssh_password" {
  type        = string
  description = "The plaintext password to use to authenticate over SSH."
  default     = ""
  sensitive   = true
}

variable "matt_password" {
  type        = string
  description = "The plaintext password to use to authenticate user matt over SSH."
  default     = ""
  sensitive   = true
}

variable "check_mk_fqdn" {
  type        = string
  description = "The fqdn of the checkmk server."
  default     = ""
  sensitive   = true
}

variable "check_mk_site" {
  type        = string
  description = "The checkmk site to join."
  default     = ""
  sensitive   = true
}

variable "check_mk_username" {
  type        = string
  description = "The username to authenticate to checkmk"
  default     = ""
  sensitive   = true
}

variable "check_mk_password" {
  type        = string
  description = "The password to authenticate to checkmk"
  default     = ""
  sensitive   = true
}

// vSphere Settings

variable "vsphere_endpoint" {
  type        = string
  description = "FQDN or IP address of vCenter"
  default     = ""
  sensitive   = true

}

variable "vsphere_username" {
  type        = string
  description = "Username to log in to vCenter"
  sensitive   = true
}

variable "vsphere_password" {
  type        = string
  description = "Password to log in to vCenter"
  sensitive   = true
}

variable "vsphere_insecure_connection" {
  type        = bool
  description = "Do not validate vCenter Server TLS certificate."
}

variable "vsphere_datacenter" {
  type        = string
  description = "The name of the target vSphere datacenter."
  default     = ""
}

variable "vsphere_cluster" {
  type        = string
  description = "The name of the target vSphere cluster."
  default     = ""
}

variable "vsphere_host" {
  type        = string
  description = "The name of the target ESXi host."
  default     = ""
}

variable "vsphere_datastore" {
  type        = string
  description = "The name of the target vSphere datastore."
}

variable "vsphere_network" {
  type        = string
  description = "The name of the target vSphere network segment."
  default = ""
}

variable "vsphere_folder" {
  type        = string
  description = "The name of the target vSphere folder."
  default     = ""
}

variable "vsphere_resource_pool" {
  type        = string
  description = "The name of the target vSphere resource pool."
  default     = ""
}

variable "vsphere_set_host_for_datastore_uploads" {
  type        = bool
  description = "Set this to true if packer should use the host for uploading files to the datastore."
  default     = false
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

variable iso_url_20{
  type = string
  description = "the url to get the ISO from for ubuntu 20/focal"
  default = ""
}

variable "iso_checksum_20" {
  type    = string
  description = "The SHA-512 checkcum of the ubuntu 20/focal ISO image."
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

variable "generic_vm_name_20" {
  type    = string
  description = "The VM name for the generic build."
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

variable "vm_guest_os_version_20" {
  type    = string
  description = "The guest operating system version for ubuntu 20/focal."
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

variable "generic_vm_boot_command_20" {
  type = list(string)
  description = "A list of boot commands."
  default = []
}

variable "vm_shutdown_command_text" {
  type = string
  description = "The string of commands issued to shut down the VM after successful build."
  default = ""
}

variable "ssh_timeout" {
  type = string
  description = "The time to wait for ssh to become available before timing out. "
  default = "30m"
}
