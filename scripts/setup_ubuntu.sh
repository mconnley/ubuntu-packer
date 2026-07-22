#!/bin/bash
##################################################################################
# Provisioning + generalization for the Ubuntu template.
#
# Runs once, as root, as the final build step. Four phases:
#   1. CONFIGURE   — put site config in place (CA trust, NTP, multipath, agent).
#   2. HARDEN      — undo the access the build itself needed.
#   3. GENERALIZE  — strip every host-specific identity so clones diverge cleanly.
#   4. VERIFY      — assert the above actually happened.
#
# The build user is NOT removed here; that happens in vm_shutdown_command, after
# this script's SSH session is finished with.
#
# Compatibility note: Ubuntu 26.04 ships uutils (Rust coreutils) instead of GNU.
# Only basic invocations are used below, which are well inside the compatible
# set — and `set -e` means anything unexpected fails the build rather than
# quietly producing a broken image.
##################################################################################

# -e           any failed command aborts the build
# -u           an unset variable (e.g. a provisioner env var never wired up) aborts
# -o pipefail  a failure inside a pipeline is not masked by a later success
#
# Without these, a 404 on the Checkmk agent or a failed dpkg would still publish
# a template. For a build nobody watches, that is the difference between a loud
# failure and months of quietly degraded images.
set -euo pipefail

log() { echo "> $*"; }

##################################################################################
# 1. CONFIGURE
##################################################################################

log "Setting timezone to ${TIMEZONE} ..."
timedatectl set-timezone "${TIMEZONE}"

log "Installing internal root CA into the system trust store ..."
# Baked in rather than left to Ansible: without it, the first TLS call a clone
# makes to an internally-signed endpoint fails — including Ansible's own.
mv /tmp/homelabrootcert.crt /usr/local/share/ca-certificates/homelabroot.crt
chmod 644 /usr/local/share/ca-certificates/homelabroot.crt
update-ca-certificates

log "Installing NTP and multipath configuration ..."
mkdir -p /etc/systemd/timesyncd.conf.d
mv /tmp/homelabntp.conf /etc/systemd/timesyncd.conf.d/homelabntp.conf
mv /tmp/multipath.conf /etc/multipath.conf

log "Staging the first-boot registration job ..."
# Credentials are substituted here rather than in the Packer template so they
# arrive via environment variables and stay out of any tracked file.
sed -i "s|REPLACE_FQDN|${CHECK_MK_FQDN}|; \
        s|REPLACE_SITE|${CHECK_MK_SITE}|; \
        s|REPLACE_USERNAME|${CHECK_MK_USERNAME}|; \
        s|REPLACE_PASSWORD|${CHECK_MK_PASSWORD}|" /tmp/postbuild_job.sh
mv /tmp/postbuild_job.sh /usr/local/bin/postbuild_job.sh
chmod 700 /usr/local/bin/postbuild_job.sh

log "Applying all available updates ..."
# The installer already pulled -security and -updates (autoinstall `updates: all`).
# This catches anything published between the ISO snapshot and this build, which
# is the whole reason the build runs nightly.
export DEBIAN_FRONTEND=noninteractive
apt-get -y update
apt-get -y dist-upgrade

log "Installing the Checkmk agent (${CHECK_MK_AGENT_VERSION}) ..."
CMK_DEB="/root/check-mk-agent_${CHECK_MK_AGENT_VERSION}_all.deb"
CMK_URL="https://${CHECK_MK_FQDN}/${CHECK_MK_SITE}/check_mk/agents/check-mk-agent_${CHECK_MK_AGENT_VERSION}_all.deb"
# wget exits non-zero on an HTTP error by default, so a retired agent version
# fails the build instead of installing an HTML error page.
wget --quiet --tries=3 "${CMK_URL}" -O "${CMK_DEB}"
dpkg -i "${CMK_DEB}"
rm -f "${CMK_DEB}"

log "Removing the unused staff group ..."
# staff carries write access to /usr/local; nothing here uses it. Guarded so a
# release that has already dropped it does not fail the build.
if getent group staff >/dev/null; then
  groupdel staff
fi

##################################################################################
# 2. HARDEN
##################################################################################

log "Reverting build-time SSH access ..."
# allow-pw and the build user's password existed only so Packer could get in.
# sshd is deliberately NOT reloaded: the running daemon keeps the old config so
# the current session survives long enough for vm_shutdown_command to run, while
# the config on disk is already hardened for every clone.
sed -i -e 's/^#\?PasswordAuthentication.*/PasswordAuthentication no/g' /etc/ssh/sshd_config
sed -i -e 's/^#\?PermitRootLogin.*/PermitRootLogin no/g' /etc/ssh/sshd_config

##################################################################################
# 3. GENERALIZE
#
# A clone must inherit nothing that makes it "this VM" — otherwise clones collide
# on DHCP leases, log identity and machine IDs.
##################################################################################

log "Cleaning apt caches ..."
apt-get -y autoremove
apt-get -y clean

log "Truncating logs ..."
for f in /var/log/audit/audit.log /var/log/wtmp /var/log/lastlog; do
  [ -f "$f" ] && : > "$f"
done
journalctl --rotate
journalctl --vacuum-time=1s

log "Masking services that are pointless on a cloned guest ..."
systemctl mask console-setup
systemctl mask fwupd-refresh
systemctl reset-failed

log "Clearing the hostname ..."
: > /etc/hostname
hostnamectl set-hostname localhost

log "Disabling swap ..."
# Swap is provisioned per-workload after deployment, not baked into the image.
swapoff -a
sed -i '/ swap / s/^\(.*\)$/#\1/g' /etc/fstab

log "Clearing the machine-id ..."
# A machine-id inherited by clones makes every clone request the same DHCP lease
# and report the same identity to the journal. Truncated rather than deleted so
# systemd regenerates it on first boot.
: > /etc/machine-id
rm -f /var/lib/dbus/machine-id
ln -s /etc/machine-id /var/lib/dbus/machine-id

log "Resetting cloud-init ..."
rm -f /etc/netplan/*
rm -f /etc/cloud/cloud.cfg.d/*.cfg
# Pin the datasource list. The stock 90_dpkg.cfg is removed with the rest of
# cloud.cfg.d above, and without a replacement cloud-init probes every datasource
# on first boot before reaching the Proxmox one.
cat > /etc/cloud/cloud.cfg.d/99-datasources.cfg <<'EOF'
datasource_list: [ NoCloud, ConfigDrive ]
EOF
cloud-init clean --logs --seed

##################################################################################
# 4. SEAL
#
# Remove the build user. This is deliberately the last mutating step: the
# proxmox-iso builder has NO shutdown_command hook — it powers the VM off
# through the Proxmox API — so this script is the last code that runs inside the
# guest, and the last opportunity to do this. If it is skipped, the account
# ships in every clone. (That is exactly how it shipped before 2026-07.)
#
# Deleting the account this SSH session authenticated as is safe: the script is
# already running as root, -f permits removal of a logged-in user, and Packer
# needs no further SSH access afterwards.
##################################################################################

log "Removing the build user (${BUILD_USER}) ..."
# userdel can exit non-zero for cosmetic reasons (absent mail spool, busy home)
# while still removing the account, so the outcome is asserted below rather than
# the exit status trusted.
userdel -rf "${BUILD_USER}" || true
rm -f "/etc/sudoers.d/${BUILD_USER}"

##################################################################################
# 5. VERIFY
#
# Assert what this script is responsible for. Without this, a silent no-op above
# ships a subtly broken template — and nobody is watching a nightly build.
##################################################################################

log "Verifying the image ..."
fail=0
check() {
  if eval "$2"; then
    echo "  ok    $1"
  else
    echo "  FAIL  $1"
    fail=1
  fi
}

check "build user removed"        '! id "${BUILD_USER}" >/dev/null 2>&1'
check "build user sudoers gone"   '[ ! -f "/etc/sudoers.d/${BUILD_USER}" ]'
check "root CA staged"            '[ -f /usr/local/share/ca-certificates/homelabroot.crt ]'
check "root CA trusted"           'ls /etc/ssl/certs/homelabroot.pem >/dev/null 2>&1'
check "NTP config in place"       '[ -f /etc/systemd/timesyncd.conf.d/homelabntp.conf ]'
check "multipath config in place" '[ -f /etc/multipath.conf ]'
check "checkmk agent installed"   'dpkg -s check-mk-agent >/dev/null 2>&1'
check "first-boot job staged"     '[ -x /usr/local/bin/postbuild_job.sh ]'
check "ansible user exists"       'id ansible >/dev/null 2>&1'
check "password auth disabled"    'grep -q "^PasswordAuthentication no" /etc/ssh/sshd_config'
check "root login disabled"       'grep -q "^PermitRootLogin no" /etc/ssh/sshd_config'
check "machine-id cleared"        '[ ! -s /etc/machine-id ]'
check "hostname cleared"          '[ ! -s /etc/hostname ]'
check "swap disabled"             '[ -z "$(swapon --show)" ]'

if [ "$fail" -ne 0 ]; then
  echo "Image verification FAILED — refusing to publish this template." >&2
  exit 1
fi

log "Image verification passed."
