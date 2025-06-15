#!/bin/bash

clear

releaseBuild=1
recoroot="/mnt/recoroot"
shimroot="/mnt/shimroot"

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
	sync
	umount /mnt/priism/ &> /dev/null
	umount /mnt/shimroot &> /dev/null
	umount /newroot &> /dev/null
	umount /mnt/recoroot &> /dev/null
	losetup -D
	hang
}

hang() {
	tput civis
	stty -echo
	sleep 1h
	echo "You really still haven't turned off your device?"
	sleep 1d
	echo "I give up. Bye."
	sleep 5
	reboot -f
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
	splashText=("       Triangle is love, triangle is life." "             Placeholder splash text" "    The lower tape fade meme is still massive" "               Now in TUI format!" " The average reaction after talking with fanqyxl" "Discord speech impediment... oh wait that's 2468")
  	selectedSplashText=${splashText[$RANDOM % ${#splashText[@]}]}
	echo -e " "
   	echo -e "$selectedSplashText"
}

funTextbutGay() {
	splashText=("Triangle is love, triangle is life." "Placeholder splash text" "The lower tape fade meme is still massive" "Now in TUI format!" "The average reaction after talking with fanqyxl" "Discord speech impediment... oh wait that's 2468")
  	selectedSplashText=${splashText[$RANDOM % ${#splashText[@]}]}
   	echo -e "$selectedSplashText"
}


detect_priism_in_shimboot_function() {
	echo "dD0oIkhlYXJzYXkhIiAiSSByZWZ1c2UuIiAiSSBzaGFsbCBkbyBubyBzdWNoIHRoaW5nISIgIkxpa2UuLi4gd2h5Pz8/IiAiSSBjZXJ0YWlubHkgd2lsbCBub3QhIiAiQXJlIHlvdSBqdXN0IGhlcmUgdG8gZGlsbHlkYWRkbGU/IiAiWW91IHJlYWxseSBoYXZlIG5vdGhpbmcgYmV0dGVyIHRvIGRvLCBkb24ndCB5b3U/IikKcz0ke3RbJFJBTkRPTSAlICR7I3RbQF19XX0KZWNobyAtZSAiICIKZWNobyAtZSAiJHMi" | base64 -d | bash
}

splash() {
	local width=48
	local verstring=${VERSION["STRING"]}
	local build=${VERSION["BUILDDATE"]}
	local version_pad=$(( (width - ${#verstring}) / 2 ))
    	local build_pad=$(( (width - ${#build}) / 2 ))
	echo -e "$COLOR_MAGENTA_B                                             ...."
	echo -e "                       ..                  ......"
	echo -e "                      .::.              ........."
	echo -e "                     .:..:.          ......:::..."
	echo -e "                    .::..::.      ..::::---:::..."
	echo -e " ........          ::::::::::  ..::-====--::.... "
	echo -e "       ...:::::...::::::::..:::-=++=--:.....     "
	echo -e "             ....----:::::::::-:.....            "
	echo -e "               .:-:.........::::.                "
	echo -e "              .............::::-:.               "
	echo -e "              ............::::::-:.              "
	echo -e "             .....::::::::::::::--:  $COLOR_RESET"
	echo -e "                     Priism                      "
	echo -e "                       or                        "
	echo -e " Portable recovery image installer/shim manager  "
	echo -e "$(printf "%*s%s" $version_pad "" "$verstring")"
	echo -e "$(printf "%*s%s" $build_pad "" "$build")"
	funText
	echo -e " "
}

# version strings: use dev, stable, or release candidate
declare -A VERSION

VERSION["BRANCH"]="stable"
VERSION["NUMBER"]="2.0"
VERSION["BUILDDATE"]="[2025-05-24]"
VERSION["STRING"]="v${VERSION["NUMBER"]} ${VERSION["BRANCH"]}"

credits() {
	echo -e "${COLOR_MAGENTA_B}Priism credits"
	echo -e "${COLOR_BLUE_B}xmb9${COLOR_RESET}: Pioneering the creation of this tool"
	echo -e "${COLOR_MAGENTA_B}Mercury Workshop${COLOR_RESET}: Finding the SH1MMER exploit"
	echo -e "${COLOR_MAGENTA_B}OlyB${COLOR_RESET}: Help with adapting wax to Priism and PID1"
	echo -e "${COLOR_MAGENTA_B}kxtzownsu${COLOR_RESET}: Help with sed syntax"
	echo -e "${COLOR_RED_B}Simon${COLOR_RESET}: Testing Priism and building the very first shims"
	echo -e "${COLOR_YELLOW_B}Darkn${COLOR_RESET}: Hosting shims"
	echo -e " "
	read -p "Press enter to continue."
	clear
	splash
}

splash
echo -e "${COLOR_YELLOW_B}Priism is currently in active development. Please report any issues you find.${COLOR_RESET}\n"

read -p "Press enter to continue."

mkdir /mnt/priism
mkdir /mnt/new_root
mkdir /mnt/shimroot
mkdir /mnt/recoroot


# Wow. Just wow.
# Why didn't I think of any of this before.
priism_images="/dev/disk/by-label/PRIISM_IMAGES"
priism_disk=$(echo /dev/$(lsblk -ndo pkname ${priism_images} || echo -e "${COLOR_YELLOW_B}Warning${COLOR_RESET}: Failed to enumerate disk! Resizing will most likely fail."))

board_name="$(cat /sys/devices/virtual/dmi/id/board_name | head -n 1)"
if ! [ $? -eq 0 ]; then
	echo -e "${COLOR_YELLOW_B}Board name detection failed. This isn't that big of an issue.${COLOR_RESET}"
 	board_name=""
fi

source /etc/lsb-release 2&> /dev/null

mount $priism_images /mnt/priism || fail "Failed to mount PRIISM_IMAGES partition!"

if [ ! -z "$(ls -A /mnt/priism/.IMAGES_NOT_YET_RESIZED 2> /dev/null)" ]; then # this janky shit is the only way it works. idk why.
	echo -e "${COLOR_YELLOW}Priism needs to resize your images partition!${COLOR_RESET}"
	
	read -p "Press enter to continue."
	
	echo -e "${COLOR_GREEN}Info: Growing PRIISM_IMAGES partition${COLOR_RESET}"
	
	umount $priism_images
	
	growpart $priism_disk 5 # growpart. why. why did you have to be different.
	e2fsck -f $priism_images
	
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

NEWROOT_MNT=/mnt/shimroot
STATEFUL_MNT=/stateful

export_args() {
  # We trust our kernel command line explicitly.
  local arg=
  local key=
  local val=
  local acceptable_set='[A-Za-z0-9]_'
  echo "Exporting kernel arguments..."
  for arg in "$@"; do
    key=$(echo "${arg%%=*}" | busybox tr 'a-z' 'A-Z' | \
                   busybox tr -dc "$acceptable_set" '_')
    val="${arg#*=}"
    export "KERN_ARG_$key"="$val"
    echo -n " KERN_ARG_$key=$val,"
  done
  echo ""
}

export_args $(cat /proc/cmdline | sed -e 's/"[^"]*"/DROPPED/g') 1> /dev/null

copy_lsb() {
  echo "Copying lsb..."

  local lsb_file="dev_image/etc/lsb-factory"
  local dest_path="${NEWROOT_MNT}/mnt/stateful_partition/${lsb_file}"
  local src_path="${STATEFUL_MNT}/${lsb_file}"

  mkdir -p "$(dirname "${dest_path}")"

  local ret=0
  if [ -f "${src_path}" ]; then
    # Convert kern_guid to uppercase and store extra info
    local kern_guid=$(echo "${KERN_ARG_KERN_GUID}" | tr '[:lower:]' '[:upper:]')
    echo "Found ${src_path}"
    cp -a "${src_path}" "${dest_path}"
    echo "REAL_USB_DEV=${loop}p3" >>"${dest_path}"
    echo "KERN_ARG_KERN_GUID=${kern_guid}" >>"${dest_path}"
  else
    echo "Failed to find ${src_path}!!"
    ret=1
  fi
  return "${ret}"
}

pv_dircopy() {
	[ -d "$1" ] || return 1
	local apparent_bytes
	apparent_bytes=$(du -sb "$1" | cut -f 1)
	mkdir -p "$2"
	tar -cf - -C "$1" . | pv -f -s "${apparent_bytes:-0}" | tar -xf - -C "$2"
}

shimboot() {
	if [[ -z "$(ls -A /mnt/priism/shims)" ]]; then
		echo -e "${COLOR_YELLOW_B}You have no shims downloaded!\nPlease download a few images for your board ${board_name} (${CHROMEOS_RELEASE_BOARD}) into the shims folder on PRIISM_IMAGES!"
		echo -e "If you have a computer running Windows, use Ext4Fsd or this chrome device. If you have a Mac, use this chrome device to download images instead.${COLOR_RESET}\n"
		shim="Exit"
	else
		echo -e "Choose the shim you want to boot:"
		select FILE in "${shimchoose[@]}" "Exit"; do
			if [[ -n "$FILE" ]]; then
				shim=$FILE
				break
			elif [[ $FILE == "Exit" ]]; then
				shim=$FILE
				break
			fi
		done
	fi

	if [[ $shim == "Exit" ]]; then
		read -p "Press enter to continue."
		clear
	else
		mkdir -p $shimroot
		echo -e "Searching for ROOT-A on shim..."
		loop=$(losetup -fP --show $shim)
		export loop

		loop_root="$(cgpt find -l ROOT-A $loop || cgpt find -t rootfs $loop)"
  		loop_root="$(echo $loop_root | head -n 1)" # there's probably way better ways to do this but i'm lazy
		loop_root="$(echo $loop_root | awk '{print $1}')" 
  
		if mount "${loop_root}" $shimroot; then
			echo -e "ROOT-A found successfully and mounted."
		else
			result=$?
			err1="Mount process failed! Exit code was ${result}.\n"
			err2="              This may be a bug! Please check your shim,\n"
			err3="              and if it looks fine, report it to the GitHub repo!\n"
			fail "${err1}${err2}${err3}"
		fi
		unpatched_shimboot=0
		if cat /mnt/shimroot/sbin/bootstrap.sh | grep "│ Shimboot OS Selector" --quiet; then
			echo -e "${COLOR_YELLOW_B}Shimboot (unpatched) detected. Please use shimboot-priism.${COLOR_RESET}"
			umount /mnt/shimroot
			losetup -D
			unpatched_shimboot=1
			read -p "Press enter to continue."
			clear
			return
		elif cat /mnt/shimroot/sbin/bootstrap.sh | grep "│ Priishimboot OS Selector" --quiet; then
			echo -e "${COLOR_GREEN}Priishimboot detected.${COLOR_RESET}"
			if ! cgpt find -l "shimboot_rootfs:priism" > /dev/null; then
				echo -e "${COLOR_YELLOW_B}Please use Priishimbooter before booting!${COLOR_RESET}"
				umount /mnt/shimroot
				losetup -D
				unpatched_shimboot=1
				read -p "Press enter to continue."
				clear
				return
			fi
		fi
		if cat /mnt/shimroot/usr/sbin/sh1mmer_main.sh | grep "Portable recovery image installer/shim manager" --quiet; then
			echo -e "${COLOR_YELLOW_B}$(detect_priism_in_shimboot_function)${COLOR_RESET}"
			losetup -D
			read -p "Press enter to continue."
			clear
			return
		fi
		if ! stateful="$(cgpt find -l STATE ${loop} | head -n 1 | grep --color=never /dev/)"; then
			echo -e "${COLOR_YELLOW_B}Finding stateful via partition label \"STATE\" failed (try 1...)${COLOR_RESET}"
			if ! stateful="$(cgpt find -l SH1MMER ${loop} | head -n 1 | grep --color=never /dev/)"; then
				echo -e "${COLOR_YELLOW_B}Finding stateful via partition label \"SH1MMER\" failed (try 2...)${COLOR_RESET}"

				for dev in "$loop"*; do
					[[ -b "$dev" ]] || continue
					parttype=$(udevadm info --query=property --name="$dev" 2>/dev/null | grep '^ID_PART_ENTRY_TYPE=' | cut -d= -f2)
					if [ "$parttype" = "0fc63daf-8483-4772-8e79-3d69d8477de4" ]; then
						stateful="$dev"
						break
					fi
				done
			fi
		fi
		if [[ -z "${stateful// }" ]]; then
			echo -e "${COLOR_RED_B}Finding stateful via partition type \"Linux data\" failed! (try 3...)${COLOR_RESET}"
			echo -e "Last resort (try 4...)"
			stateful="${loop}p1"
		fi

		if (( $unpatched_shimboot == 0 )); then
			mkdir -p /stateful
			mkdir -p /newroot

			mount -t tmpfs tmpfs /newroot -o "size=1024M" || fail "Could not allocate 1GB of TMPFS to the newroot mountpoint."
			mount $stateful /stateful || fail "Failed to mount stateful partition!"

			copy_lsb

			echo "Copying rootfs to ram."
			pv_dircopy "$shimroot" /newroot

			echo "Moving mounts..."
			mkdir -p "/newroot/dev" "/newroot/proc" "/newroot/sys" "/newroot/tmp" "/newroot/run"
			mount -t tmpfs -o mode=1777 none /newroot/tmp
			mount -t tmpfs -o mode=0555 run /newroot/run
			mkdir -p -m 0755 /newroot/run/lock

			umount -l /dev/pts
			umount -f /dev/pts

			mounts=("/dev" "/proc" "/sys")
			for mnt in "${mounts[@]}"; do
				mount --move "$mnt" "/newroot$mnt"
				umount -l "$mnt"
			done

			echo "Done."
			echo "About to switch root. If your screen goes black and the device reboots, it may be a bug. Please make a GitHub issue if you're sure your shim isn't corrupted."
			sleep 1
			echo "Switching root!"
			clear

			mkdir -p /newroot/tmp/priism
			pivot_root /newroot /newroot/tmp/priism

			echo "Starting init"
   			if [ -f "/bin/kvs" ]; then
        			exec /bin/kvs
			fi

			exec /sbin/init || {
				echo "Failed to start init!!!"
				echo "Bailing out, you are on your own. Good luck."
				echo "This shell has PID 1. Exit = panic."
				/tmp/priism/bin/uname -a
				exec /tmp/priism/bin/sh
			}
		fi
	fi
}


installcros() {
	if [[ -z "$(ls -A /mnt/priism/recovery)" ]]; then
		echo -e "${COLOR_YELLOW_B}You have no recovery images downloaded!\nPlease download a few images for your board ${board_name} (${CHROMEOS_RELEASE_BOARD}) into the recovery folder on PRIISM_IMAGES!"
		echo -e "These are available on websites such as chrome100.dev, or cros.tech."
		echo -e "Chrome100 hosts old and new recovery images, whereas cros.tech only hosts the latest images."
		echo -e "If you have a computer running Windows, use Ext4Fsd or this chrome device. If you have a Mac, use this chrome device to download images instead.${COLOR_RESET}\n"
		reco="Exit"
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
	else
		mkdir -p $recoroot
		echo -e "Searching for ROOT-A on reco image..."
		loop=$(losetup -fP --show $reco)
		loop_root="$(cgpt find -l ROOT-A $loop | head -n 1)" # Usually the 3rd partition is always the "real" ROOT-A
		if mount -r "${loop_root}" $recoroot ; then
			echo -e "ROOT-A found successfully and mounted."
		else
 			result=$?
			err1="Mount process failed! Exit code was ${result}.\n"
			err2="              This may be a bug! Please check your recovery image,\n"
			err3="              and if it looks fine, report it to the GitHub repo!\n"
			fail "${err1}${err2}${err3}"
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
		local cros_dev="$(get_largest_cros_blockdev)"
		if [ -z "$cros_dev" ]; then
			echo -e "${COLOR_YELLOW_B}No ChromeOS drive was found on the device! Please make sure ChromeOS is installed before using Priism. Continuing anyway...${COLOR_RESET}"
		fi
		export IS_RECOVERY_INSTALL=1
		chroot ./ /usr/sbin/chromeos-install --payload_image="${loop}" --yes || fail "Failed during chroot!"
		# Juusst in case.
		cgpt add -i 2 $cros_dev -P 15 -T 15 -S 1 -R 1 || echo -e "${COLOR_YELLOW_B}Failed to set kernel priority! Continuing anyway.${COLOR_RESET}"
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
		sync
		reboot -f
		sleep 1
		echo -e "${COLOR_RED_B}Reboot failed. Hanging..."
		hang
	else
		echo -e "Use the bash shell to reboot."
	fi
	read -p "Press enter to continue."
	clear
}

shutdowndevice() {
	if [[ releaseBuild -eq 1 ]]; then
		echo -e "Shutting down..."
		sync
		poweroff -f
		sleep 1
		echo -e "${COLOR_RED_B}Shutdown failed. Hanging..."
		hang
	else
		echo -e "Use the bash shell to shutdown."
	fi
	read -p "Press enter to continue."
	clear
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
	clear
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
	else
		source $payload
		read -p "Press enter to continue."
		clear
	fi
}

changelog() {
	cat /changelog.txt | busybox less
	read -p "Press enter to continue."
	clear
}

if [[ releaseBuild -eq 1 ]]; then
	OPTIONS=$'Bash shell\nBoot an RMA shim\nInstall a ChromeOS recovery image\nPayloads\nCredits\nChangelog\nReboot\nPower off'
else
	OPTIONS=$'Bash shell\nBoot an RMA shim\nInstall a ChromeOS recovery image\nPayloads\nCredits\nChangelog\nReboot\nPower off\nExit [Debug]'
fi

while true; do
	shmenu -o "$OPTIONS" -p "Main menu - Priism [${VERSION[STRING]}] - $(funTextbutGay)"
	option=$(cat /tmp/shmenu_choice)
	clear
	case "$option" in
		"Bash shell") bash ;;
		"Boot an RMA shim") shimboot ;;
		"Install a ChromeOS recovery image") installcros ;;
		"Payloads") payloads ;;
		"Credits") credits ;;
		"Changelog") changelog ;;
		"Reboot") rebootdevice ;;
		"Power off") shutdowndevice ;;
		"Exit [Debug]") exitdebug ;;
		*) echo -e "You entered an invalid option (${option})... Somehow."; sleep 1 ;;
	esac
	echo -e ""
done
