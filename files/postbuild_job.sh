#!/bin/bash
rm /etc/salt/minion_id
hostname > /etc/salt/minion_id
systemctl enable salt-minion
systemctl start salt-minion
rm /usr/local/bin/postbuild_job.sh