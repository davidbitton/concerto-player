mkdiskimage -z -M concerto.img 1024M
LOOP_DEV=`losetup --show -f concerto.img`
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

# create squashfs filesystem
mkdir $MOUNTPOINT/live
mksquashfs $CHROOT_DIR $MOUNTPOINT/live/concerto.squashfs

# copy other needed files into chroot

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

sleep 1

# clean up after ourselves
umount $MOUNTPOINT
rmdir $MOUNTPOINT
partx -d $LOOP_DEV
losetup -d $LOOP_DEV
