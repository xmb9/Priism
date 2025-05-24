#!/bin/bash

source /etc/profile

echo "Starting dbus..."
mkdir -p /run/dbus
mkdir -p /var/lib/dbus
chown messagebus:messagebus /run/dbus

if [ ! -e /var/run ]; then
	ln -s /run /var/run # Lazy.
fi

rm -f /var/lib/dbus/machine-id
dbus-uuidgen --ensure

# dbus-daemon --system --fork

