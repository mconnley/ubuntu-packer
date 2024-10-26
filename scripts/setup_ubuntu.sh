#!/bin/bash
echo '> Moving firstboot script...'
mv /tmp/postbuild_job.sh /usr/local/bin/postbuild_job.sh
echo ' Setting firstboot script to executable...'
chmod +x /usr/local/bin/postbuild_job.sh
echo '> Moving NTP config...'
mkdir /etc/systemd/timesyncd.conf.d
mv /tmp/homelabntp.conf /etc/systemd/timesyncd.conf.d/homelabntp.conf
mv /tmp/multipath.conf /etc/multipath.conf
echo '> Executing apt-get dist-upgrade...'
apt-get -y dist-upgrade
echo '> Installing Checkmk Agent...'
wget http://checkmk.mattconnley.com/homelab/check_mk/agents/check-mk-agent_2.3.0p12-1_all.deb -O /root/check-mk-agent_2.3.0p12-1_all.deb
dpkg -i /root/check-mk-agent_2.3.0p12-1_all.deb
rm /root/check-mk-agent_2.3.0p12-1_all.deb
echo '> Cleaning apt-get ...'
apt-get -y autoremove
apt-get -y clean
echo '> Cleaning up salt minion...'
rm /etc/salt/minion_id
echo '> Enabling VMWare custom scripts...'
vmware-toolbox-cmd config set deployPkg enable-custom-scripts true
echo '> Cleaning all audit logs ...'
if [ -f /var/log/audit/audit.log ]; then
cat /dev/null > /var/log/audit/audit.log
fi
if [ -f /var/log/wtmp ]; then
cat /dev/null > /var/log/wtmp
fi
if [ -f /var/log/lastlog ]; then
cat /dev/null > /var/log/lastlog
fi
echo '> Masking console-setup service...'
systemctl mask console-setup
echo '> Masking fwupd-refresh service...'
systemctl mask fwupd-refresh
echo '> Rotating and vacuuming journal...'
journalctl --rotate
journalctl --vacuum-time=1s
echo '> Resetting failed systemd services...'
systemctl reset-failed
echo '> Setting hostname to localhost ...'
cat /dev/null > /etc/hostname
hostnamectl set-hostname localhost

echo '> Disabling swap...'
swapoff -a
sed -i '/ swap / s/^\(.*\)$/#\1/g' /etc/fstab

echo '> Cleaning the machine-id ...'
truncate -s 0 /etc/machine-id
rm /var/lib/dbus/machine-id
ln -s /etc/machine-id /var/lib/dbus/machine-id

echo '> Resetting Cloud-Init'
rm /etc/cloud/cloud.cfg.d/*.cfg -f
rm /etc/netplan/* -f
cloud-init clean -s -l