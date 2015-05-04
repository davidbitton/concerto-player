#!/bin/sh -e

if [ "`whoami`" != "root" ]; then
	# check if sudo is available, if not error out
	if command -v sudo >/dev/null 2>&1; then
		echo This script needs root privileges to run.
		echo Press enter to attempt to run under sudo.
		echo Press ctrl-C to quit.
		read dummyvar
		exec sudo $0
	else
		echo This script needs root privileges to run.
		exit 1
	fi
fi

# drop existimg .img and create a fresh one
file="concerto.img"
[[ -f "$file" ]] && rm -f "$file"
mkdiskimage -z -M "$file" 1024M

LOOP_DEV=`losetup --show -f "$file"`
PARTITION_NO="p1"
PARTITION=$LOOP_DEV$PARTITION_NO
CHROOT_DIR=chroot
partx -a $LOOP_DEV

# install bootloader
syslinux -i $PARTITION

# figure out a place we can mount this
TMP_DIR="/tmp"
RAND_NAME=`head -c512 /dev/urandom | md5sum | head -c8`
MOUNTPOINT=$TMP_DIR/$RAND_NAME
mkdir $MOUNTPOINT

# mount partition so we can copy files over
mount $PARTITION $MOUNTPOINT

# free any handles on chroot by dbus-daemon (lsof chroot)
fuser -k ${CHROOT_DIR}

# create squashfs filesystem
mkdir $MOUNTPOINT/live
mksquashfs $CHROOT_DIR $MOUNTPOINT/live/concerto.squashfs

# copy other needed files from chroot into boot medium

# There should only be one kernel/initrd.img pair. So we just find it and copy it.
KERNEL=`ls $CHROOT_DIR/boot | grep vmlinuz | head -1`
INITRD=`ls $CHROOT_DIR/boot | grep initrd.img | head -1`
cp $CHROOT_DIR/boot/$KERNEL $CHROOT_DIR/boot/$INITRD $MOUNTPOINT 

# generate a syslinux config.
cat > $MOUNTPOINT/syslinux.cfg <<EOF
DEFAULT concerto
LABEL concerto
KERNEL $KERNEL
APPEND boot=live initrd=$INITRD
EOF

# generate a xrandr.sh file for custom xrandr commands
cat > $MOUNTPOINT/xrandr.sh << EOF
#!/bin/bash
xrandr -d :0 --newmode "1920x1080_60.00"  173.00  1920 2048 2248 2576  1080 1083 1088 1120 -hsync +vsync
xrandr -d :0 --addmode "1920x1080_60.00"
xrandr -d :0 --output Virtual1 --mode "1920x1080_60.00"
EOF

# clean up after ourselves
sleep 1
umount $MOUNTPOINT
rmdir $MOUNTPOINT
partx -d $LOOP_DEV
losetup -d $LOOP_DEV
