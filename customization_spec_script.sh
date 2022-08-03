#!/bin/sh
if [ x$1 = x"precustomization" ]; then
 echo Do Precustomization tasks
elif [ x$1 = x"postcustomization" ]; then
 echo Do Postcustomization tasks
 deluser --remove-home packer
 systemctl enable salt-minion
 systemctl start salt-minion
fi