#!/bin/sh
if [ x$1 = x"precustomization" ]; then
 echo Do Precustomization tasks
elif [ x$1 = x"postcustomization" ]; then
 echo Do Postcustomization tasks
 deluser --remove-home packer
 /usr/local/bin/postbuild_job.sh
fi