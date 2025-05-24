#!/bin/bash

source /etc/profile
echo "Starting udevd..."
/sbin/udevd --daemon || :
udevadm trigger || :
udevadm settle || :
echo "Done."
