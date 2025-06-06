##################################################################################
# VARIABLES
##################################################################################

# HTTP Settings

http_directory = "http"

# Virtual Machine Settings
vm_cpu_sockets              = 2
vm_cpu_cores                = 1
vm_mem_size                 = 2048
vm_disk_size                = "4G"
vm_boot_wait                = "8s"
vm_shutdown_command_text    = "sudo su root -c \"userdel -rf packer; shutdown -P now\""
ssh_timeout                 = "45m"
vm_scsi_controller          = "virtio-scsi-pci"

noble_vm_boot_command = [
    "c<wait3s>",
    "linux /casper/vmlinuz ip=192.168.2.233::192.168.2.1:255.255.255.0::::192.168.2.33:192.168.2.34:192.168.2.1 --- autoinstall ipv6.disable=1 ds=\"nocloud-net;seedfrom=http://{{.HTTPIP}}:{{.HTTPPort}}/noble/\"",
    "<enter><wait3s>",
    "initrd /casper/initrd",
    "<enter><wait3s>",
    "boot",
    "<enter>"
  ]

noble_vm_name               = "ubuntu-noble-template"

# ISO Objects
iso_url                    = "https://releases.ubuntu.com/jammy/ubuntu-22.04.5-live-server-amd64.iso"
iso_checksum               = "9bc6028870aef3f74f4e16b900008179e78b130e6b0b9a140635434a46aa98b0"

iso_url_noble              = "https://releases.ubuntu.com/noble/ubuntu-24.04.2-live-server-amd64.iso"
iso_checksum_noble         = "d6dab0c3a657988501b4bd76f1297c053df710e06e0c3aece60dead24f270b4d"

# Scripts
shell_scripts               = ["./scripts/setup_ubuntu.sh"]