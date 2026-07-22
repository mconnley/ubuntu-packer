##################################################################################
# Ubuntu 24.04 LTS "Noble Numbat"
#
# Supported to April 2029. The base for every existing non-Talos Linux VM.
##################################################################################

release_codename = "noble"
release_version  = "24.04"

# The point release in this filename is removed from releases.ubuntu.com once
# superseded, so this needs a bump roughly twice a year. The build fails loudly
# on a 404 when that happens — that is intentional. Nothing here floats.
iso_url = "https://releases.ubuntu.com/24.04/ubuntu-24.04.4-live-server-amd64.iso"

# Packer fetches SHA256SUMS and matches the entry for the ISO filename above, so
# the checksum itself never needs hand-maintaining.
iso_checksum = "file:https://releases.ubuntu.com/24.04/SHA256SUMS"

vm_name = "ubuntu-noble-template"
vm_id   = 100
