#!/bin/bash

source /etc/environment

echo "Populating /dev, /proc, /sys..."

mount -n -t proc -o nodev,noexec,nosuid proc /proc
mount -n -t sysfs -o nodev,noexec,nosuid sysfs /sys
mount -t tmpfs tmp /tmp

mount -t devtmpfs -o mode=0755,nosuid devtmpfs /dev
ln -sf /proc/self/fd /dev/fd || :
ln -sf fd/0 /dev/stdin || :
ln -sf fd/1 /dev/stdout || :
ln -sf fd/2 /dev/stderr || :

mkdir -p /dev/pts
mount -n -t devpts -o noexec,nosuid devpts /dev/pts || :

mount -n -t debugfs debugfs /sys/kernel/debug

echo "Done."
