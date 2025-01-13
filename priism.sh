#!/bin/bash

clear

releaseBuild=0
recoroot="/mnt/recoroot"

COLOR_RESET="\033[0m"
COLOR_BLACK_B="\033[1;30m"
COLOR_RED_B="\033[1;31m"
COLOR_GREEN="\033[0;32m"
COLOR_GREEN_B="\033[1;32m"
COLOR_YELLOW="\033[0;33m"
COLOR_YELLOW_B="\033[1;33m"
COLOR_BLUE_B="\033[1;34m"
COLOR_MAGENTA_B="\033[1;35m"
COLOR_CYAN_B="\033[1;36m"

if [[ $releaseBuild -eq 1 ]]; then
	trap '' INT
fi

get_largest_cros_blockdev() {
	local largest size dev_name tmp_size remo
	size=0
	for blockdev in /sys/block/*; do
		dev_name="${blockdev##*/}"
		echo -e "$dev_name" | grep -q '^\(loop\|ram\)' && continue
		tmp_size=$(cat "$blockdev"/size)
		remo=$(cat "$blockdev"/removable)
		if [ "$tmp_size" -gt "$size" ] && [ "${remo:-0}" -eq 0 ]; then
			case "$(sfdisk -d "/dev/$dev_name" 2>/dev/null)" in
				*'name="STATE"'*'name="KERN-A"'*'name="ROOT-A"'*)
					largest="/dev/$dev_name"
					size="$tmp_size"
					;;
			esac
		fi
	done
	echo -e "$largest"
}

funText() {
	splashText=("       Triangle is love, triangle is life." "             Placeholder splash text")
  	selectedSplashText=${splashText[$RANDOM % ${#splashText[@]}]}
	echo -e " "
   	echo -e "$selectedSplashText"
}

splash() {
	echo -e "$COLOR_MAGENTA_B                                              ...."
	echo -e "                        ..                  ......"
	echo -e "                       .::.              ........."
	echo -e "                      .:..:.          ......:::..."
	echo -e "                     .::..::.      ..::::---:::..."
	echo -e "  ........          ::::::::::  ..::-====--::.... "
	echo -e "        ...:::::...::::::::..:::-=++=--:.....     "
	echo -e "              ....----:::::::::-:.....            "
	echo -e "                .:-:.........::::.                "
	echo -e "               .............::::-:.               "
	echo -e "               ............::::::-:.              "
	echo -e "              .....::::::::::::::--:  $COLOR_RESET"
	echo -e "                      Priism                      "
	echo -e "                        or                        "
	echo -e "  Portable recovery image installer/shim manager  "
	echo -e "                      v1.0p                       "
	funText
	echo -e " "
}

splash
echo -e "${COLOR_YELLOW_B}THIS IS A PROTOTYPE BUILD, DO NOT EXPECT EVERYTHING TO WORK PROPERLY!!!${COLOR_RESET}"

mkdir /mnt/priism
mkdir /mnt/new_root
mkdir /mnt/shimroot
mkdir /mnt/recoroot

priism_images="$(cgpt find -l PRIISM_IMAGES | head -n 1 | grep --color=never /dev/)"
priism_disk="$(echo "$priism_images" | sed -E 's/(.*[0-9]+)$/\1/')"
board_name="$(cat /sys/devices/virtual/dmi/id/board_name | head -n 1)"
mount $priism_images /mnt/priism

if [ -d "$priism_images/.IMAGES_NOT_YET_RESIZED" ]; then
	echo -e "${COLOR_YELLOW}Priism needs to resize your images partition!${COLOR_RESET}"
	read -p "Press enter to continue."
	echo -e "${COLOR_GREEN}Info: Growing PRIISM_IMAGES partition"
	umount $priism_images
	growpart $priism_disk 5
	e2fsck -f $priism_images
	resize2fs $priism_images
	echo -e "${COLOR_GREEN}Done. Remounting partition..."
	mount $priism_images /mnt/priism
	rm $priism_images/.IMAGES_NOT_YET_RESIZED
fi

recochoose=(/mnt/priism/recovery/*)
shimchoose=(/mnt/priism/shims/*)


shimboot() {
	find /mnt/priism/shims -type f
	while true; do
		read -p "Please choose a shim to boot: " shimtoboot
		
		if [[ $shimtoboot == "exit" ]]
		then
			break
		fi
		
		if [[ ! -f /mnt/priism/shims/$shimtoboot ]]
		then
			echo -e "File not found! Try again."
		else
			echo -e "Function not yet implemented."
		fi
	done
	read -p "Press enter to continue."
	losetup -D
	splash
}

installcros() {
	if [ -z "$(ls -A /mnt/priism/recovery)" ]; then
		echo -e "${COLOR_YELLOW_B}You have no recovery images downloaded!\nPlease download a few images for your board (${board_name})\ninto the recovery folder on PRIISM_IMAGES!"
		echo -e "These are available on websites such as chrome100.dev, or cros.tech."
		echo -e "Chrome100 hosts old and new recovery images, whereas cros.tech only hosts the latest images."
		echo -e "If you have a computer running Windows, use Ext4Fsd or this chrome device.\nIf you have a Mac, use this chrome device to download images instead.${COLOR_RESET}\n"
		read -p "Press enter to continue."
		splash
	fi
	echo -e "Choose the image you want to flash, or type exit:"
	select FILE in "${recochoose[@]}"; do
 		if [[ -n "$FILE" ]]; then
			reco=$FILE
			break
		fi
	done
		
	if [[ $reco == "exit" ]]; then
		read -p "Press enter to continue."
		splash
	fi
  
	mkdir -p $recoroot

	echo -e "Searching for ROOT-A on reco image..."
	loop=$(losetup -fP --show $reco)
	loop_root="$(cgpt find -l ROOT-A $loop)"
	if mount -r "${loop_root}" $recoroot ; then
		echo -e "ROOT-A found successfully and mounted."
	else
 		result=$?
		echo -e "${COLOR_RED_B}Mount process failed! Exit code was ${result}."
		echo -e "This may be a bug! Please check your recovery image,"
		echo -e "and if it looks fine, report it to the GitHub repo!${COLOR_RESET}"
		echo -e " "
  		read -p "Press enter to continue."
		losetup -D
		splash
	fi

	mount -t proc /proc $recoroot/proc/
	mount --rbind /sys $recoroot/sys/
	mount --rbind /dev $recoroot/dev/

	local cros_dev="$(get_largest_cros_blockdev)"
	if [ -z "$cros_dev" ]; then
		echo -e "${COLOR_RED_B}No CrOS SSD found on device!${COLOR_RESET}"
		read -p "Press enter to continue."
		splash
	fi

	/mnt/recoroot/usr/sbin/chromeos-recovery $loop
	
	echo -e "chromeos-recovery returned exit code $?."
	echo -e "Before rebooting, Priism needs to set priority to the newly installed kernel."
	read -p "Press enter to continue."
	cgpt add -i 2 $cros_dev -P 15 -T 15 -S 1 -R 1
	read -p "${COLOR_GREEN}Recovery finished. Press any key to reboot."
	reboot
	echo -e "${COLOR_RED_B}Reboot failed. Hanging..."
	while :; do sleep 1d; done
}

rebootdevice() {
	if [[ releaseBuild -eq 1 ]]; then
		echo -e "Rebooting..."
		reboot
		echo -e "${COLOR_RED_B}Reboot failed. Hanging..."
		while :; do sleep 1d; done
	else
		echo -e "Use the bash shell to reboot."
	fi
	read -p "Press enter to continue."
	splash # This should never be reached on releaseBuilds
}

shutdowndevice() {
	if [[ releaseBuild -eq 1 ]]; then
		echo -e "Shutting down..."
		shutdown -h now
		echo -e "${COLOR_RED_B}Shutdown failed. Hanging..."
		while :; do sleep 1d; done
	else
		echo -e "Use the bash shell to shutdown."
	fi
	read -p "Press enter to continue."
	splash
}

exitdebug() {
        if [[ releaseBuild -eq 0 ]]; then
		echo -e "${COLOR_YELLOW_B}Exit is only meant to be used when"
		echo -e "testing Priism outside of shims!"
		echo -e "Are you sure you want to do this?${COLOR_RESET}"
		read -p "(y/n) >" exitask
		if [[ $exitask == "y" ]]; then
                	umount /mnt/recoroot > /dev/null
			umount /mnt/shimroot > /dev/null
			umount /mnt/new_root > /dev/null
			umount /mnt/priism > /dev/null
			losetup -D > /dev/null
			rm -rf /mnt/recoroot
                	rm -rf /mnt/priism
                	rm -rf /mnt/shimroot
                	rm -rf /mnt/new_root
                	exit
		else
			echo -e "Cancelled."
		fi
        else
                echo -e "This option is only available on debug builds."
        fi
	read -p "Press enter to continue."
	splash
}

sh1mmer() {
        if [[ releaseBuild -eq 0 ]]; then
		bash sh1mmer_main_old.sh || echo -e "${COLOR_RED_B}Failed to run sh1mmer!${COLOR_RESET}"
        else
                echo -e "This option is only available on debug builds."
        fi
	read -p "Press enter to continue."
	splash
}

while true; do
	echo -e "Select an option:"
	echo -e "(1 or b) Bash shell"
	echo -e "(2 or s) Boot an RMA shim"
	echo -e "(3 or i) Install a ChromeOS recovery image"
	echo -e "(4 or r) Reboot"
	echo -e "(5 or p) Power off"
	if [[ releaseBuild -eq 0 ]]; then
		echo -e "(6 or h) Run sh1mmer_main.sh [Debug]"
		echo -e "(7 or e) Exit [Debug]"
	fi
	read -p "> " choice
	case "$choice" in
	1| b | B) bash ;;
	2 | s | S) shimboot ;;
	3 | i | I) installcros ;;
	4 | R | R) rebootdevice ;;
	5 | p | P) shutdowndevice ;;
	6 | h | H) sh1mmer ;;
	7 | e | E) exitdebug ;;
	*) echo -e "Invalid option" ;;
	esac
	echo -e ""
done
