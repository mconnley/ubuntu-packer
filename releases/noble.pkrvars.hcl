##################################################################################
# Ubuntu 24.04 LTS "Noble Numbat"
#
# Supported to April 2029. The base for every existing non-Talos Linux VM.
##################################################################################

release_codename = "noble"
release_version  = "24.04"

# The point release in iso_url/iso_filename is removed from releases.ubuntu.com
# once superseded, so both need a bump roughly twice a year. When iso_filename
# changes, the pool cache misses and ensure_iso pulls the new ISO automatically.
iso_url      = "https://releases.ubuntu.com/24.04/ubuntu-24.04.4-live-server-amd64.iso"
iso_checksum = "file:https://releases.ubuntu.com/24.04/SHA256SUMS"
iso_filename = "ubuntu-24.04.4-live-server-amd64.iso"

template_name  = "ubuntu-noble-template"
template_vm_id = 100  # production template clones use
build_vm_id    = 9100 # disposable; promoted onto template_vm_id on success
