##################################################################################
# Ubuntu 26.04 LTS "Resolute Raccoon"
#
# Released 2026-04-23, supported to April 2031.
#
# Two changes in this release affect the build; both are handled in shared code,
# not here, so they are documented at the point of the fix:
#
#   * sudo-rs replaces sudo as the default. It does not support -E/--preserve-env
#     (trifectatechfoundation/sudo-rs#1299, open). The provisioner therefore uses
#     `sudo env {{.Vars}}` rather than `sudo -E` — see ubuntu.pkr.hcl.
#   * uutils (Rust coreutils) replaces GNU coreutils as the default, at roughly
#     88% GNU test-suite parity. The provisioning script uses only basic
#     invocations, and `set -euo pipefail` turns any surprise into a failed build
#     rather than a silently broken image — see scripts/setup_ubuntu.sh.
#
# Unchanged and verified: /casper/vmlinuz + /casper/initrd boot paths, the
# `autoinstall` kernel argument, and the subiquity `version: 1` schema.
##################################################################################

release_codename = "resolute"
release_version  = "26.04"

# 26.04.1 is due 2026-08-04 and will rename these to ubuntu-26.04.1-..., retiring
# the current files. Expect a one-line bump of iso_url + iso_filename around then;
# ensure_iso pulls the new ISO automatically once iso_filename changes.
iso_url      = "https://releases.ubuntu.com/26.04/ubuntu-26.04-live-server-amd64.iso"
iso_checksum = "file:https://releases.ubuntu.com/26.04/SHA256SUMS"
iso_filename = "ubuntu-26.04-live-server-amd64.iso"

template_name  = "ubuntu-resolute-template"
template_vm_id = 500  # production template clones use
build_vm_id    = 9500 # disposable; promoted onto template_vm_id on success
