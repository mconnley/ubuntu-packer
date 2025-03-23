# ubuntu-packer

v0.9.0

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
vsphere_endpoint                = "vCenter_fqdn"
vsphere_username                = "vCenter_username"
vsphere_password                = "vCenter_password"
vsphere_datastore               = "template_datastore"
vsphere_network                 = "template_network_name"
vsphere_cluster                 = "cluster_name"
```
