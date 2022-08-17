# ubuntu-packer

Root CA cert should be /files/secure/homelabrootcert.crt

Requires sensitive.variables.pkr.hcl in root folder, should be like:

```
ssh_username                    = "username_for_packer_ssh"
ssh_password                    = "password_for_packer_ssh"
matt_password                   = "password_for_matt"
check_mk_username               = "username_for_check_mk"
check_mk_password               = "password_for_check_mk"
check_mk_fqdn                   = "checkmk.domain.tld"
check_mk_site                   = "thissite"
```
 