#!/bin/bash

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

fail() {
	printf "${COLOR_RED_B}%b${COLOR_RESET}\n" "$*" >&2 || :
	exit 1
}

[ "$EUID" -ne 0 ] && fail "Please run as root"
IMAGE=$1
DEVICE=$2

ARCHITECTURE="$(uname -m)"
case "$ARCHITECTURE" in
	*x86_64* | *x86-64*) ARCHITECTURE=x86_64 ;;
	*aarch64* | *armv8*) ARCHITECTURE=aarch64 ;;
	*i[3-6]86*) ARCHITECTURE=i386 ;;
	*) fail "Unsupported architecture $ARCHITECTURE" ;;
esac

[ -z "$1" ] && fail "Specify a sh1mmer legacy image (Feb 2024+) to modify!"
[ -z "$2" ] && fail "Specify a block device (e.g /dev/sda) to update!"

bash priism_builder.sh $IMAGE || fail "Failed to build Priism image!"

losetup -Pf $IMAGE

CGPT="lib/$ARCHITECTURE/cgpt"
chmod +x "$CGPT"

LOOP_PART=$("$CGPT" find -l SH1MMER /dev/loop* 2> /dev/null | grep "/dev/loop" --color=never | head -n 1) || fail "Failed to get SH1MMER partition on loop device"
DEVICE_PART=$("$CGPT" find -l SH1MMER "$DEVICE" 2> /dev/null | grep "$DEVICE" --color=never | head -n 1) || fail "Failed to get SH1MMER partition on ${DEVICE}"
IMAGES_PART_LOOP=$("$CGPT" find -l PRIISM_IMAGES /dev/loop* 2> /dev/null | grep "/dev/loop" --color=never | head -n 1) || fail "Failed to get PRIISM_IMAGES partition on ${DEVICE}"
IMAGES_PART=$("$CGPT" find -l PRIISM_IMAGES "$DEVICE"* 2> /dev/null | grep "$DEVICE" --color=never | head -n 1) || fail "Failed to get PRIISM_IMAGES partition on ${DEVICE}"

echo "SH1MMER partition on loop device is: ${LOOP_PART}"
echo "SH1MMER partition on ${DEVICE} is: ${DEVICE_PART}"
echo "PRIISM_IMAGES partition on loop device is: ${IMAGES_PART_LOOP}"
echo "PRIISM_IMAGES partition on ${DEVICE} is: ${IMAGES_PART}"

echo -e "${COLOR_YELLOW_B}About to flash SH1MMER partition on ${DEVICE}! Data loss could possibly occur!${COLOR_RESET}"
echo -e "Please make sure the above partition values look correct!"
read -p "Press enter to continue, or CTRL+C to exit."
echo -e "${COLOR_YELLOW_B}Flashing partition in 5 seconds... press CTRL+C NOW to cancel!"
sleep 5
echo -e "${COLOR_GREEN}Info: Beginning flash...${COLOR_RESET}"
dd if="$LOOP_PART" of="$DEVICE_PART" status=progress || fail "An error occurred during flashing. Please report this, it could be bad!"
sync
echo -e "${COLOR_GREEN}Info: Copying payloads to PRIISM_IMAGES...${COLOR_RESET}"
MNT_IMAGES=$(mktemp -d)
MNT_IMAGES_LOOP=$(mktemp -d)
mount "$IMAGES_PART" "$MNT_IMAGES"
mount "$IMAGES_PART_LOOP" "$MNT_IMAGES_LOOP"
mkdir "$MNT_IMAGES/payloads/"
cp -vR "$MNT_IMAGES_LOOP"/payloads/* "$MNT_IMAGES"/payloads/
sync
sync
sync
sleep 0.2
umount "$MNT_IMAGES"
umount "$MNT_IMAGES_LOOP"
umount /tmp/tmp.* 2&> /dev/null # Failsafe umount. I fucking hate loopback devices.
losetup --detach-all
echo -e "${COLOR_GREEN}Done. Have fun!${COLOR_RESET}"
