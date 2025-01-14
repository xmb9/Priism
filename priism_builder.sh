#!/usr/bin/env bash

IMAGE=$1
SCRIPT_DIR=$(dirname "$0")
SCRIPT_DIR=${SCRIPT_DIR:-"."}
. "$SCRIPT_DIR/wax_common.sh"

set -eE

[ "$EUID" -ne 0 ] && fail "Please run as root"
[ -z "$1" ] && echo "Specify a sh1mmer legacy image (Feb 2024+) to modify with 'priism_builder.sh image.bin'"

cleanup() {
	[ -d "$MNT_SH1MMER" ] && umount "$MNT_SH1MMER" && rmdir "$MNT_SH1MMER"
	[ -z "$LOOPDEV" ] || losetup -d "$LOOPDEV" || :	
	trap - EXIT INT
}

patch_sh1mmer() {
	log_info "Creating Priism images partition ($(format_bytes $SH1MMER_PART_SIZE))"
	local sector_size=$(get_sector_size "$LOOPDEV")
	cgpt_add_auto "$IMAGE" "$LOOPDEV" 5 $((SH1MMER_PART_SIZE / sector_size)) -t data -l PRIISM_IMAGES
	mkfs.ext2 -F -b 4096 -L PRIISM_IMAGES "${LOOPDEV}p5"
	
	safesync
	suppress sgdisk -e "$IMAGE" 2>&1 | sed 's/\a//g'
	safesync

	MNT_SH1MMER=$(mktemp -d)
	MNT_priism=$(mktemp -d)
	mount "${LOOPDEV}p1" "$MNT_SH1MMER"

	log_info "Copying payload"
	mv "$MNT_SH1MMER/root/noarch/usr/sbin/sh1mmer_main.sh" "$MNT_SH1MMER/root/noarch/usr/sbin/sh1mmer_main_old.sh"
	cp priism.sh "$MNT_SH1MMER/root/noarch/usr/sbin/sh1mmer_main.sh"
	cp priism_init.sh "$MNT_SH1MMER/bootstrap/noarch/init_sh1mmer.sh"
	cp growpart.sh "$MNT_SH1MMER/root/noarch/usr/sbin/growpart"
	chmod -R +x "$MNT_SH1MMER"

	umount "$MNT_SH1MMER"
	rmdir "$MNT_SH1MMER"

	mount "${LOOPDEV}p5" "$MNT_priism"

	mkdir "$MNT_priism/shims"
	mkdir "$MNT_priism/recovery"
	touch "$MNT_priism/.IMAGES_NOT_YET_RESIZED"
	safesync
	umount $MNT_priism
	rmdir $MNT_priism
}

trap 'echo $BASH_COMMAND failed with exit code $?. THIS IS A BUG, PLEASE REPORT!' ERR
trap 'cleanup; exit' EXIT
trap 'echo Abort.; cleanup; exit' INT
FLAGS_sh1mmer_part_size=64M
		
if [ -b "$IMAGE" ]; then
	log_info "Image is a block device, performance may suffer..."
else
	check_file_rw "$IMAGE" || fail "$IMAGE doesn't exist, isn't a file, or isn't RW"
	check_slow_fs "$IMAGE"
fi

check_gpt_image "$IMAGE" || fail "$IMAGE is not GPT, or is corrupted"

SH1MMER_PART_SIZE=$(parse_bytes "$FLAGS_sh1mmer_part_size") || fail "Could not parse size '$FLAGS_sh1mmer_part_size'"

sudo dd if=/dev/zero bs=1MiB of="$IMAGE" conv=notrunc oflag=append count=100
# sane backup table
suppress sgdisk -e "$IMAGE" 2>&1 | sed 's/\a//g'

log_info "Correcting GPT errors"
suppress fdisk "$IMAGE" <<EOF
w
EOF


log_info "Creating loop device"
LOOPDEV=$(losetup -f)
losetup -P "$LOOPDEV" "$IMAGE"
safesync

patch_sh1mmer
safesync

losetup -d "$LOOPDEV"
safesync

suppress sgdisk -e "$IMAGE" 2>&1 | sed 's/\a//g'

log_info "Done. Have fun!"
trap - EXIT
