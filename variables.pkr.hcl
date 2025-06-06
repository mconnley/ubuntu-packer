variable "proxmox_url" {
  type        = string
  description = "The URL of the Proxmox server."
  default     = ""
  sensitive   = true
}

variable "proxmox_username" {
  type        = string
  description = "The username to authenticate to Proxmox."
  default     = ""
  sensitive   = true
}

variable "proxmox_token" {
  type        = string
  description = "The Proxmox API token to use for authentication."
  default     = ""
  sensitive   = true
}

variable "proxmox_node" {
  type        = string
  description = "The Proxmox node to use for the build."
  default     = ""
}

variable "proxmox_task_timeout" {
  type        = string
  description = "The timeout for Proxmox tasks."
  default     = "30m"
}

variable "iso_storage_pool" {
  type        = string
  description = "The storage pool to use for ISO images."
  default     = "local"
}

variable "vm_os" {
  type        = string
  description = "The operating system type for the VM."
  default     = "l26"
}

variable "vm_scsi_controller" {
  type        = string
  description = "The type of SCSI controller to use for the VM."
  default     = "virtio-scsi-pci"
}

variable "vm_network_model" {
  type        = string
  description = "The network model for the VM."
  default     = "virtio"
}

variable "vm_network_bridge" {
  type        = string
  description = "The network bridge to connect the VM to."
  default     = "vmbr0"
}

variable "vm_storage_pool" {
  type        = string
  description = "The storage pool to use for the VM."
  default     = "local-lvm"
}

variable "vm_disk_type" {
  type        = string
  description = "The type of disk to use for the VM."
  default     = "scsi"
}
variable "vm_disk_discard" {
  type        = bool
  description = "Whether to enable discard for the VM disk."
  default     = true
}

variable "vm_disk_format" {
  type        = string
  description = "The format of the VM disk."
  default     = "qcow2"
}
variable "vm_disk_iothread" {
  type        = bool
  description = "Whether to enable I/O threads for the VM disk."
  default     = false
}
variable "vm_disk_ssd" {
  type        = bool
  description = "Whether the VM disk is on SSD storage."
  default     = false
}
variable "vm_shutdown_timeout" {
  type        = string
  description = "The timeout for the VM shutdown command."
  default     = "5m"
}

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

variable iso_url_noble{
  type = string
  description = "the url to get the ISO from"
  default = ""
}

variable "iso_checksum_noble" {
  type    = string
  description = "The SHA-512 checkcum of the ISO image."
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
  type = string
  description = "The size of the disk, including a unit suffix, such as 10G to indicate 10 gigabytes"
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

variable "noble_vm_boot_command" {
  type = list(string)
  description = "A list of boot commands."
  default = []
}


variable "noble_vm_name" {
  type    = string
  description = "The VM name for the Noble build."
  default = ""
}
