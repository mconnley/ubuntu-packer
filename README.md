# ubuntu-packer

v0.10.0

Root CA cert should be /files/secure/homelabrootcert.crt

Requires sensitive.variables.pkr.hcl in root folder, should be like:

```
ssh_username                    = "username_for_packer_ssh"
ssh_password                    = "password_for_packer_ssh"
matt_password                   = "password_for_matt"
check_mk_fqdn                   = "checkmk.domain.tld"
check_mk_site                   = "checkmk-site-name"
check_mk_username               = "check_mk_username"
check_mk_password               = "check_mk_password"
proxmox_url                     = "https://someproxmoxhost.domain.tld:8006/api2/json"
proxmox_username                = "root@pam!someuser"
proxmox_token                   = "proxmox-token-guid-"
proxmox_node                    = "someproxmoxhost"
iso_storage_pool                = "nfs-storage-pool"
vm_storage_pool                 = "vm-storage-pool"
```
