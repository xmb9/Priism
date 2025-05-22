#!/bin/bash
echo -e "${COLOR_YELLOW_B}You will not be able to return to Priism again in this session once you do this!"
read -p "Press 'y' to continue." -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]
then
	cp /usr/sbin/sh1mmer_main_old.sh /usr/sbin/sh1mmer_main.sh
	exec /sbin/init
	fail "Failed to execute /sbin/init! Somehow..."
else
	echo "Cancelled."
fi
