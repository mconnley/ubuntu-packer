##################################################################################
# VARIABLES
##################################################################################

# HTTP Settings

http_directory = "http"

# Virtual Machine Settings

vm_guest_os_family          = "linux"
vm_guest_os_vendor          = "ubuntu"
vm_guest_os_member          = "server"
vm_guest_os_version         = "22-04-lts"
vm_guest_os_type            = "ubuntu-64"
vm_version                  = 19
vm_firmware                 = "bios"
vm_cdrom_type               = "sata"
vm_cpu_sockets              = 2
vm_cpu_cores                = 1
vm_mem_size                 = 2048
vm_disk_size                = 16384
vm_disk_controller_type     = ["pvscsi"]
vm_network_card             = "vmxnet3"
vm_boot_wait                = "5s"
vm_shutdown_command_text    = "sudo su root -c \"userdel -rf packer; shutdown -P now\""

generic_vm_boot_command = [
    "c<wait>",
    "linux /casper/vmlinuz --- autoinstall ds=\"nocloud-net;seedfrom=http://{{.HTTPIP}}:{{.HTTPPort}}/generic/\"",
    "<enter><wait>",
    "initrd /casper/initrd",
    "<enter><wait>",
    "boot",
    "<enter>"
  ]

rancher_vm_boot_command = [
    "c<wait>",
    "linux /casper/vmlinuz --- autoinstall ds=\"nocloud-net;seedfrom=http://{{.HTTPIP}}:{{.HTTPPort}}/rancher/\"",
    "<enter><wait>",
    "initrd /casper/initrd",
    "<enter><wait>",
    "boot",
    "<enter>"
  ]

rancherlonghorn_vm_boot_command = [
    "c<wait>",
    "linux /casper/vmlinuz --- autoinstall ds=\"nocloud-net;seedfrom=http://{{.HTTPIP}}:{{.HTTPPort}}/rancherlonghorn/\"",
    "<enter><wait>",
    "initrd /casper/initrd",
    "<enter><wait>",
    "boot",
    "<enter>"
  ]

generic_vm_name             = "ubuntu_template"
rancher_vm_name             = "ubuntu_rancher_template"
rancherlonghorn_vm_name     = "ubuntu_rancher_longhorn_template"

# ISO Objects

#iso_url                    = "https://releases.ubuntu.com/focal/ubuntu-20.04.4-live-server-amd64.iso"
iso_url                    = "https://releases.ubuntu.com/22.04/ubuntu-22.04-live-server-amd64.iso"
#iso_checksum                = "28ccdb56450e643bad03bb7bcf7507ce3d8d90e8bf09e38f6bd9ac298a98eaad"
iso_checksum                = "84aeaf7823c8c61baa0ae862d0a06b03409394800000b3235854a6b38eb4856f"

# Scripts

shell_scripts               = ["./scripts/setup_ubuntu2004.sh"]