#!/bin/bash
echo -e "${COLOR_YELLOW_B}You will not be able to return to Priism again in this session once you do this!"
read -p "Press 'y' to continue." -n 1 -r
echo -e "${COLOR_RESET}"
if [[ $REPLY =~ ^[Yy]$ ]]
then
	if [[ -f /usr/sbin/sh1mmer_main_old.sh ]]; then
		cp -f /usr/sbin/sh1mmer_main_old.sh /usr/sbin/sh1mmer_main.sh || { echo "Failed to restore sh1mmer_main; aborting."; exit 1; }
	else
		echo "Missing sh1mmer_main_old.sh; aborting."
		exit 1
	fi
	if [[ -f /bin/init_sh1mmer_old.sh ]]; then
		mv -f /bin/init_sh1mmer_old.sh /bin/init_sh1mmer.sh
	fi
	if [[ -f /sbin/init_sh1mmer_old_elf ]]; then
		cp -f /sbin/init_sh1mmer_old_elf /sbin/init || { echo "Failed to restore original init; aborting."; exit 1; }
	elif [[ -f /usr/sbin/sh1mmer_init_old ]]; then
		cp -f /usr/sbin/sh1mmer_init_old /sbin/init || { echo "Failed to restore original init; aborting."; exit 1; }
	elif [[ -f /sbin/sh1mmer_init_old ]]; then
		cp -f /sbin/sh1mmer_init_old /sbin/init || { echo "Failed to restore original init; aborting."; exit 1; }
	else
		echo "Missing init_sh1mmer_old_elf; aborting."
		exit 1
	fi
	chmod +x /sbin/init
	touch /tmp/priism_boot_sh1mmer
	exit 0
else
	echo "Cancelled."
fi
