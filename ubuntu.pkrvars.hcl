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
    "linux /casper/vmlinuz ip=192.168.2.230::192.168.2.1:255.255.255.0::::192.168.2.33:192.168.2.34:192.168.2.1 --- autoinstall ipv6.disable=1 ds=\"nocloud-net;seedfrom=http://{{.HTTPIP}}:{{.HTTPPort}}/generic/\"",
    "<enter><wait>",
    "initrd /casper/initrd",
    "<enter><wait>",
    "boot",
    "<enter>"
  ]

rancher_vm_boot_command = [
    "c<wait3s>",
    "linux /casper/vmlinuz ip=192.168.2.231::192.168.2.1:255.255.255.0::::192.168.2.33:192.168.2.34:192.168.2.1 --- autoinstall ipv6.disable=1 ds=\"nocloud-net;seedfrom=http://{{.HTTPIP}}:{{.HTTPPort}}/rancher/\"",
    "<enter><wait3s>",
    "initrd /casper/initrd",
    "<enter><wait3s>",
    "boot",
    "<enter>"
  ]

rancherlonghorn_vm_boot_command = [
    "c<wait3s>",
    "linux /casper/vmlinuz ip=192.168.2.232::192.168.2.1:255.255.255.0::::192.168.2.33:192.168.2.34:192.168.2.1 --- autoinstall ipv6.disable=1 ds=\"nocloud-net;seedfrom=http://{{.HTTPIP}}:{{.HTTPPort}}/rancherlonghorn/\"",
    "<enter><wait3s>",
    "initrd /casper/initrd",
    "<enter><wait3s>",
    "boot",
    "<enter>"    
  ]

noble_vm_boot_command = [
    "c<wait3s>",
    "linux /casper/vmlinuz ip=192.168.2.233::192.168.2.1:255.255.255.0::::192.168.2.33:192.168.2.34:192.168.2.1 --- autoinstall ipv6.disable=1 ds=\"nocloud-net;seedfrom=http://{{.HTTPIP}}:{{.HTTPPort}}/noble/\"",
    "<enter><wait3s>",
    "initrd /casper/initrd",
    "<enter><wait3s>",
    "boot",
    "<enter>"
  ]

generic_vm_name             = "ubuntu_template"
rancher_vm_name             = "ubuntu_rancher_template"
rancherlonghorn_vm_name     = "ubuntu_rancher_longhorn_template"
noble_vm_name               = "ubuntu_noble_template"

# ISO Objects
iso_url                    = "https://releases.ubuntu.com/jammy/ubuntu-22.04.5-live-server-amd64.iso"
iso_checksum               = "9bc6028870aef3f74f4e16b900008179e78b130e6b0b9a140635434a46aa98b0"

iso_url_noble              = "https://releases.ubuntu.com/24.04.1/ubuntu-24.04.1-live-server-amd64.iso"
iso_checksum_noble         = "e240e4b801f7bb68c20d1356b60968ad0c33a41d00d828e74ceb3364a0317be9"

# Scripts
shell_scripts               = ["./scripts/setup_ubuntu.sh"]