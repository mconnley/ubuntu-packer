##################################################################################
# VARIABLES
##################################################################################

# HTTP Settings

http_directory = "http"

# Virtual Machine Settings
vsphere_insecure_connection  = true
vm_guest_os_family          = "linux"
vm_guest_os_vendor          = "ubuntu"
vm_guest_os_member          = "server"
vm_guest_os_version         = "22-04-lts"
vm_guest_os_version_20      = "22-04-lts"
vm_guest_os_type            = "ubuntu64Guest"
vm_version                  = 21
vm_firmware                 = "bios"
vm_cdrom_type               = "sata"
vm_cpu_sockets              = 2
vm_cpu_cores                = 1
vm_mem_size                 = 2048
vm_disk_size                = 16384
vm_disk_controller_type     = ["pvscsi"]
vm_network_card             = "vmxnet3"
vm_boot_wait                = "8s"
vm_shutdown_command_text    = "sudo su root -c \"userdel -rf packer; shutdown -P now\""
vm_docker_disk_size         = 98304
vm_longhorn_disk_size       = 65536
ssh_timeout                 = "45m"

generic_vm_boot_command = [
    "c<wait>",
    "linux /casper/vmlinuz ip=192.168.2.230::192.168.2.1:255.255.255.0::::192.168.2.33:192.168.2.34:192.168.2.1 --- autoinstall ds=\"nocloud-net;seedfrom=http://{{.HTTPIP}}:{{.HTTPPort}}/generic/\"",
    "<enter><wait>",
    "initrd /casper/initrd",
    "<enter><wait>",
    "boot",
    "<enter>"
  ]

rancher_vm_boot_command = [
    "c<wait>",
    "linux /casper/vmlinuz ip=192.168.2.231::192.168.2.1:255.255.255.0::::192.168.2.33:192.168.2.34:192.168.2.1 --- autoinstall ds=\"nocloud-net;seedfrom=http://{{.HTTPIP}}:{{.HTTPPort}}/rancher/\"",
    "<enter><wait>",
    "initrd /casper/initrd",
    "<enter><wait>",
    "boot",
    "<enter>"
  ]

rancherlonghorn_vm_boot_command = [
    "c<wait>",
    "linux /casper/vmlinuz ip=192.168.2.232::192.168.2.1:255.255.255.0::::192.168.2.33:192.168.2.34:192.168.2.1 --- autoinstall ds=\"nocloud-net;seedfrom=http://{{.HTTPIP}}:{{.HTTPPort}}/rancherlonghorn/\"",
    "<enter><wait>",
    "initrd /casper/initrd",
    "<enter><wait>",
    "boot",
    "<enter>"
  ]

generic_vm_boot_command_20 = [
    " <wait><enter><wait>",
    "<f6><esc>",
    "<bs><bs><bs><bs><bs><bs><bs><bs><bs><bs>",
    "<bs><bs><bs><bs><bs><bs><bs><bs><bs><bs>",
    "<bs><bs><bs><bs><bs><bs><bs><bs><bs><bs>",
    "<bs><bs><bs><bs><bs><bs><bs><bs><bs><bs>",
    "<bs><bs><bs><bs><bs><bs><bs><bs><bs><bs>",
    "<bs><bs><bs><bs><bs><bs><bs><bs><bs><bs>",
    "<bs><bs><bs><bs><bs><bs><bs><bs><bs><bs>",
    "<bs><bs><bs><bs><bs><bs><bs><bs><bs><bs>",
    "<bs><bs><bs>",
    "/casper/vmlinuz ",
    "initrd=/casper/initrd --- ",
    "autoinstall ",
    "ds=nocloud-net;seedfrom=http://{{.HTTPIP}}:{{.HTTPPort}}/generic20/",
    "<enter>"
    ]

generic_vm_name             = "ubuntu_template"
generic_vm_name_20          = "ubuntu_template_20"
rancher_vm_name             = "ubuntu_rancher_template"
rancherlonghorn_vm_name     = "ubuntu_rancher_longhorn_template"

# ISO Objects

iso_url                    = "https://releases.ubuntu.com/jammy/ubuntu-22.04.4-live-server-amd64.iso"
iso_checksum               = "45f873de9f8cb637345d6e66a583762730bbea30277ef7b32c9c3bd6700a32b2"

iso_url_20                 = "https://releases.ubuntu.com/focal/ubuntu-20.04.6-live-server-amd64.iso"
iso_checksum_20            = "b8f31413336b9393ad5d8ef0282717b2ab19f007df2e9ed5196c13d8f9153c8b"


# Scripts
shell_scripts               = ["./scripts/setup_ubuntu.sh"]