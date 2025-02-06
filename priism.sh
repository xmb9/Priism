#!/bin/bash

clear

releaseBuild=1
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

fail() {
	printf "Priism panic: ${COLOR_RED_B}%b${COLOR_RESET}\n" "$*" >&2 || :
	printf "panic: We are hanging here..." 
	hang
}

hang() {
	tput civis
	stty -echo
	while :; do sleep 1d; done
}

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
	splashText=("       Triangle is love, triangle is life." "             Placeholder splash text" "    The lower tape fade meme is still massive")
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
	echo -e "                   v1.1 stable                    "
	funText
	echo -e " "
}

credits() {
	echo -e "${COLOR_MAGENTA_B}Priism credits"
	echo -e "${COLOR_BLUE_B}Ethereal Workshop${COLOR_RESET}: Developers behind Priism"
	echo -e "${COLOR_BLUE_B}Archimax${COLOR_RESET}: Pioneering the creation of this tool"
	echo -e "${COLOR_MAGENTA_B}Mercury Workshop${COLOR_RESET}: Finding the SH1MMER exploit"
	echo -e "${COLOR_MAGENTA_B}OlyB${COLOR_RESET}: Help with adapting wax to Priism and PID1"
	echo -e "${COLOR_MAGENTA_B}kxtzownsu${COLOR_RESET}: Help with sed syntax"
	echo -e "${COLOR_RED_B}simpamsoftware${COLOR_RESET}: Testing Priism and building the very first shims"
	echo -e "${COLOR_YELLOW_B}Darkn${COLOR_RESET}: Hosting shims"
	echo -e " "
	read -p "Press enter to continue."
	clear
	splash
}

splash
echo -e "${COLOR_YELLOW_B}Priism is currently in active development. Please report any issues you find.${COLOR_RESET}\n"

mkdir /mnt/priism
mkdir /mnt/new_root
mkdir /mnt/shimroot
mkdir /mnt/recoroot

priism_images="$(cgpt find -l PRIISM_IMAGES | head -n 1 | grep --color=never /dev/)" || fail "Failed to find PRIISM_IMAGES partition!"
priism_disk="$(echo "$priism_images" | sed -E 's/(mmcblk[0-9]+)p[0-9]+$/\1/; s/(sd[a-z])[0-9]+$/\1/')" || fail "Failed to find Priism disk!" # what the fuck?
board_name="$(cat /sys/devices/virtual/dmi/id/board_name | head -n 1)" || fail "Could not get board name!"
mount $priism_images /mnt/priism || fail "Failed to mount PRIISM_IMAGES partition!"

if [ ! -z "$(ls -A /mnt/priism/.IMAGES_NOT_YET_RESIZED 2> /dev/null)" ]; then # this janky shit is the only way it works. idk why.
	echo -e "${COLOR_YELLOW}Priism needs to resize your images partition!${COLOR_RESET}"
	
	read -p "Press enter to continue."
	
	echo -e "${COLOR_GREEN}Info: Growing PRIISM_IMAGES partition${COLOR_RESET}"
	
	umount $priism_images
	
	growpart $priism_disk 5 || fail "Failed to grow partition 5 on ${priism_disk}!" # growpart. why. why did you have to be different.
	e2fsck -f $priism_images || fail "Failed to repair partition 5 on ${priism_disk}!"
	
	echo -e "${COLOR_GREEN}Info: Resizing filesystem (This operation may take a while, do not panic if it looks stuck!)${COLOR_RESET}"
	
	resize2fs -p $priism_images || fail "Failed to resize filesystem on ${priism_images}!"
	
	echo -e "${COLOR_GREEN}Done. Remounting partition...${COLOR_RESET}"
	
	mount $priism_images /mnt/priism
	rm -rf /mnt/priism/.IMAGES_NOT_YET_RESIZED
	sync
fi

chmod 777 /mnt/priism/*

recochoose=(/mnt/priism/recovery/*)
shimchoose=(/mnt/priism/shims/*)
selpayload=(/mnt/priism/payloads/*.sh)

shimboot() {
	# find /mnt/priism/shims -type f
	# while true; do
		#read -p "Please choose a shim to boot: " shimtoboot
		#
		#if [[ $shimtoboot == "exit" ]]
		#then
		# 	break
		#fi
		#
		#if [[ ! -f /mnt/priism/shims/$shimtoboot ]]
		#then
		#	echo -e "File not found! Try again."
		#else
		#	echo -e "Function not yet implemented."
		#fi
	#done
	echo -e "${COLOR_RED_B}Function not yet implemented!${COLOR_RESET}\n"
	read -p "Press enter to continue."
	#losetup -D
	clear
	splash
}

installcros() {
	if [[ -z "$(ls -A /mnt/priism/recovery)" ]]; then
		echo -e "${COLOR_YELLOW_B}You have no recovery images downloaded!\nPlease download a few images for your board (${board_name}) into the recovery folder on PRIISM_IMAGES!"
		echo -e "These are available on websites such as chrome100.dev, or cros.tech."
		echo -e "Chrome100 hosts old and new recovery images, whereas cros.tech only hosts the latest images."
		echo -e "If you have a computer running Windows, use Ext4Fsd or this chrome device. If you have a Mac, use this chrome device to download images instead.${COLOR_RESET}\n"
		reco="exit"
	else
		echo -e "Choose the image you want to flash:"
		select FILE in "${recochoose[@]}" "Exit"; do
 			if [[ -n "$FILE" ]]; then
				reco=$FILE
				break
			elif [[ $FILE == "Exit" ]]; then
				reco=$FILE
				break
			fi
		done
	fi
		
	if [[ $reco == "Exit" ]]; then
		read -p "Press enter to continue."
		clear
		splash
	else
		mkdir -p $recoroot
		echo -e "Searching for ROOT-A on reco image..."
		loop=$(losetup -fP --show $reco)
		loop_root="$(cgpt find -l ROOT-A $loop)"
		if mount -r "${loop_root}" $recoroot ; then
			echo -e "ROOT-A found successfully and mounted."
		else
 			result=$?
			err1="Mount process failed! Exit code was ${result}.\n"
			err2="              This may be a bug! Please check your recovery image,\n"
			err3="              and if it looks fine, report it to the GitHub repo!\n"
			fail "${err1}${err2}${err3}"
		fi
		local cros_dev="$(get_largest_cros_blockdev)"
		if [ -z "$cros_dev" ]; then
			fail "No CrOS drive found on device! Please make sure ChromeOS is installed before using Priism."
		fi
		stateful="$(cgpt find -l STATE ${loop} | head -n 1 | grep --color=never /dev/)" || fail "Failed to find stateful partition on ${loop}!"
		mount $stateful /mnt/stateful_partition || fail "Failed to mount stateful partition!"
		MOUNTS="/proc /dev /sys /tmp /run /var /mnt/stateful_partition" 
		cd /mnt/recoroot/
		d=
		for d in ${MOUNTS}; do
	  		mount -n --bind "${d}" "./${d}"
	  		mount --make-slave "./${d}"
		done
		chroot ./ /usr/sbin/chromeos-install --payload_image "${loop}" --dst "${cros_dev}" --yes || fail "Failed during chroot!"
		cgpt add -i 2 $cros_dev -P 15 -T 15 -S 1 -R 1 || fail "Failed to set kernel priority!"
		echo -e "${COLOR_GREEN}\n"
		read -p "Recovery finished. Press any key to reboot."
		reboot
		sleep 1
		echo -e "\n${COLOR_RED_B}Reboot failed. Hanging..."
		hang
	fi
}

rebootdevice() {
	if [[ releaseBuild -eq 1 ]]; then
		echo -e "Rebooting..."
		reboot
		sleep 1
		echo -e "${COLOR_RED_B}Reboot failed. Hanging..."
		hang
	else
		echo -e "Use the bash shell to reboot."
	fi
	read -p "Press enter to continue."
	clear
	splash # This should never be reached on releaseBuilds
}

shutdowndevice() {
	if [[ releaseBuild -eq 1 ]]; then
		echo -e "Shutting down..."
		shutdown -h now
		sleep 1
		echo -e "${COLOR_RED_B}Shutdown failed. Hanging..."
		hang
	else
		echo -e "Use the bash shell to shutdown."
	fi
	read -p "Press enter to continue."
	clear
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

payloads() {
	echo -e "Choose payload to run:"
	select FILE in "${selpayload[@]}" "Exit"; do
 		if [[ -n "$FILE" ]]; then
			payload=$FILE
			break
		elif [[ "$FILE" == "Exit" ]]; then
			payload=$FILE
			break
		fi
	done
	if [[ $payload == "Exit" ]]; then
		read -p "Press enter to continue."
		clear
		splash
	else
		bash $payload
		read -p "Press enter to continue."
		clear
		splash
	fi
}

while true; do
	echo -e "Select an option:"
	echo -e "(1 or b) Bash shell"
	echo -e "(2 or s) Boot an RMA shim (Not implemented yet!)"
	echo -e "(3 or i) Install a ChromeOS recovery image"
	echo -e "(4 or a) Payloads"
	echo -e "(5 or c) Credits"
	echo -e "(6 or r) Reboot"
	echo -e "(7 or p) Power off"
	if [[ releaseBuild -eq 0 ]]; then
		echo -e "(8 or e) Exit [Debug]"
	fi
	read -p "> " choice
	case "$choice" in
	1| b | B) bash ;;
	2 | s | S) shimboot ;;
	3 | i | I) installcros ;;
	4 | a | A) payloads ;;
	5 | c | C) credits ;;
	6 | r | R) rebootdevice ;;
	7 | p | P) shutdowndevice ;;
	8 | e | E) exitdebug ;;
	*) clear && echo -e "Invalid option $choice" ;;
	esac
	echo -e ""
done
