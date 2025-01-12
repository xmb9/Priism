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
		echo "$dev_name" | grep -q '^\(loop\|ram\)' && continue
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
	echo "$largest"
}

funText() {
	splashText=("       Triangle is love, triangle is life." "             Placeholder splash text")
  	selectedSplashText=${splashText[$RANDOM % ${#splashText[@]}]}
	echo " "
   	echo "$selectedSplashText"
}

splash() {
	echo "$COLOR_MAGENTA_B                                              ...."
	echo "                        ..                  ......"
	echo "                       .::.              ........."
	echo "                      .:..:.          ......:::..."
	echo "                     .::..::.      ..::::---:::..."
	echo "  ........          ::::::::::  ..::-====--::.... "
	echo "        ...:::::...::::::::..:::-=++=--:.....     "
	echo "              ....----:::::::::-:.....            "
	echo "                .:-:.........::::.                "
	echo "               .............::::-:.               "
	echo "               ............::::::-:.              "
	echo "              .....::::::::::::::--:  $COLOR_RESET"
	echo "                      Priism                      "
	echo "                        or                        "
	echo "  Portable recovery image installer/shim manager  "
	echo "                      v1.0p                       "
	funText
	echo " "
}

splash
echo "${COLOR_YELLOW_B}THIS IS A PROTOTYPE BUILD, DO NOT EXPECT EVERYTHING TO WORK PROPERLY!!!${COLOR_RESET}"

mkdir /mnt/priism
mkdir /mnt/new_root
mkdir /mnt/shimroot
mkdir /mnt/recoroot

priism_images="$(cgpt find -l PRIISM_IMAGES | head -n 1 | grep --color=never /dev/)"
mount $priism_images /mnt/priism

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
			echo "File not found! Try again."
		else
			echo "Function not yet implemented."
		fi
	done
	read -p "Press enter to continue."
	losetup -D
	splash
}

installcros() {
	echo "Choose the image you want to flash, or type exit:"
	select FILE in "${recochoose[@]}"; do
 		if [[ -n "$FILE" ]]; then
			reco=$FILE
			break
		fi
	done
		
	if [[ $reco == "exit" ]]; then
		break
	fi
  
	mkdir -p $recoroot

	echo "Searching for ROOT-A on reco image..."
	loop=$(losetup -fP --show $reco)
	loop_root="$(cgpt find -l ROOT-A $loop)"
	if mount -r "${loop_root}" $recoroot ; then
		echo "ROOT-A found successfully and mounted."
	else
 		result=$?
		echo "${COLOR_RED_B}Mount process failed! Exit code was ${result}."
		echo "This may be a bug! Please check your recovery image,"
		echo "and if it looks fine, report it to the GitHub repo!${COLOR_RESET}"
		echo " "
  		read -p "Press enter to continue."
		losetup -D
		splash
	fi

	mount -t proc /proc $recoroot/proc/
	mount --rbind /sys $recoroot/sys/
	mount --rbind /dev $recoroot/dev/

	local cros_dev="$(get_largest_cros_blockdev)"
	if [ -z "$cros_dev" ]; then
		echo "${COLOR_RED_B}No CrOS SSD found on device!${COLOR_RESET}"
		read -p "Press enter to continue."
		splash
	fi

	/mnt/recoroot/usr/sbin/chromeos-recovery $loop
	
	echo "chromeos-recovery returned exit code $?."
	echo "Before rebooting, Priism needs to set priority to the newly installed kernel."
	read -p "Press enter to continue."
	cgpt add -i 2 $cros_dev -P 15 -T 15 -S 1 -R 1
	read -p "${COLOR_GREEN}Recovery finished. Press any key to reboot."
	reboot
	echo "${COLOR_RED_B}Reboot failed. Hanging..."
	while :; do sleep 1d; done
}

rebootdevice() {
	if [[ releaseBuild -eq 1 ]]; then
		echo "Rebooting..."
		reboot
		echo "${COLOR_RED_B}Reboot failed. Hanging..."
		while :; do sleep 1d; done
	else
		echo "Use the bash shell to reboot."
	fi
	read -p "Press enter to continue."
	splash # This should never be reached on releaseBuilds
}

shutdowndevice() {
	if [[ releaseBuild -eq 1 ]]; then
		echo "Shutting down..."
		shutdown -h now
		echo "${COLOR_RED_B}Shutdown failed. Hanging..."
		while :; do sleep 1d; done
	else
		echo "Use the bash shell to shutdown."
	fi
	read -p "Press enter to continue."
	splash
}

exitdebug() {
        if [[ releaseBuild -eq 0 ]]; then
		echo "${COLOR_YELLOW_B}Exit is only meant to be used when"
		echo "testing Priism outside of shims!"
		echo "Are you sure you want to do this?${COLOR_RESET}"
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
			echo "Cancelled."
		fi
        else
                echo "This option is only available on debug builds."
        fi
	read -p "Press enter to continue."
	splash
}

sh1mmer() {
        if [[ releaseBuild -eq 0 ]]; then
		bash sh1mmer_main_old.sh || echo "${COLOR_RED_B}Failed to run sh1mmer!${COLOR_RESET}"
        else
                echo "This option is only available on debug builds."
        fi
	read -p "Press enter to continue."
	splash
}

while true; do
	echo "Select an option:"
	echo "(1 or b) Bash shell"
	echo "(2 or s) Boot an RMA shim"
	echo "(3 or i) Install a ChromeOS recovery image"
	echo "(4 or r) Reboot"
	echo "(5 or p) Power off"
	if [[ releaseBuild -eq 0 ]]; then
		echo "(6 or h) Run sh1mmer_main.sh [Debug]"
		echo "(7 or e) Exit [Debug]"
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
	*) echo "Invalid option" ;;
	esac
	echo ""
done
