#!/bin/bash

clear

releaseBuild=0
recoroot="/mnt/recoroot"

if [[ $releaseBuild -eq 1 ]]; then
	trap '' INT
fi

funText() {
	splashText=("       Triangle is love, triangle is life." "             Placeholder splash text")
  	selectedSplashText=${splashText[$RANDOM % ${#splashText[@]}]}
	echo " "
   	echo "$selectedSplashText"
}

splash() {
	echo "                                              ...."
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
	echo "              .....::::::::::::::--:              "
	echo "                      Priism                      "
	echo "                        or                        "
	echo "  Portable recovery image installer/shim manager  "
	echo "                      v0.9a                       "
	funText
	echo " "
}

splash
echo "THIS IS A PROTOTYPE BUILD, DO NOT EXPECT EVERYTHING TO WORK PROPERLY!!!"

mkdir /mnt/priism
mkdir /mnt/new_root
mkdir /mnt/shimroot
mkdir /mnt/recoroot

priism_images="$(cgpt find -l PRIISM_IMAGES | head -n 1 | grep --color=never /dev/)"
# mount $priism_images /mnt/priism

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
	read -p "Press any key to continue"
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
	loop_root="$(cgpt find -l ${loop} ROOT-A | head -n 1 | grep --color=never /dev/)"
	if mount -r "${loop_root}" $recoroot ; then
		result=$?
		echo "ROOT-A found successfully and mounted."
	else
		echo "Mount process failed! Exit code was ${result}."
		echo "This may be a bug! Please check your recovery image,"
		echo "and if it looks fine, report it to the GitHub repo!"
  		break
	fi

	mount -t proc /proc $recoroot/proc/
	mount --rbind /sys $recoroot/sys/
	mount --rbind /dev $recoroot/dev/

	/mnt/recoroot/usr/sbin/chromeos-recovery $loop
}

rebootdevice() {
	if [[ releaseBuild -eq 1 ]]; then
		echo "Rebooting..."
		reboot
	else
		echo "Use the bash shell to reboot."
	fi
}

shutdowndevice() {
	if [[ releaseBuild -eq 1 ]]; then
		echo "Shutting down..."
		shutdown -h now
	else
		echo "Use the bash shell to shutdown."
	fi
}

exitdebug() {
        if [[ releaseBuild -eq 0 ]]; then
                umount /mnt/recoroot
		umount /mnt/shimroot
		umount /mnt/new_root
		rm -rf /mnt/recoroot
                rm -rf /mnt/priism
                rm -rf /mnt/shimroot
                rm -rf /mnt/new_root
                exit
        else
                echo "Invalid option"
        fi
}

sh1mmer() {
        if [[ releaseBuild -eq 0 ]]; then
		bash sh1mmer_main_old.sh || echo "Failed to run sh1mmer"
        else
                echo "Invalid option"
        fi
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
