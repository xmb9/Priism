#!/bin/bash
echo -e "${COLOR_YELLOW_B}You will not be able to return to Priism again in this session once you do this!"
read -p "Press 'y' to continue." -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]
then
	if [[ -f /usr/sbin/sh1mmer_main_old.sh ]]; then
		mv -f /usr/sbin/sh1mmer_main_old.sh /usr/sbin/sh1mmer_main.sh
	else
		echo "Missing sh1mmer_main_old.sh; aborting."
		exit 1
	fi
	if [[ -f /usr/sbin/sh1mmer_init_old ]]; then
		mv -f /usr/sbin/sh1mmer_init_old /sbin/init
	else
		echo "Missing sh1mmer_init_old; aborting."
		exit 1
	fi
	exec /sbin/init
	fail "Failed to execute /sbin/init! Somehow..."
else
	echo "Cancelled."
	echo -e "${COLOR_RESET}"
fi
