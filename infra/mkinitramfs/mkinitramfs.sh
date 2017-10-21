#!/bin/bash
# This file based in part on the mkinitramfs script for the LFS LiveCD
# written by Alexander E. Patrakov and Jeremy Huntwork.
# Modified for use with AI\OS.

copy()
{
  local file

  if [ "$2" == "lib" ]; then
    file=/lib/$(basename $1)
  else
    file=/bin/$1
  fi

  if [ -n "$file" ] ; then
    cp $file $WDIR/$2
  else
    echo "Missing required file: $1 for directory $2"
    rm -rf $WDIR
    exit 1
  fi
}

if [ -n $1 ] ; then KERNEL_VERSION=$1; fi
if [ -n $2 ] ; then ROOTDIR=$2; fi

if [ -n "$KERNEL_VERSION" ] && [ ! -d "/lib/modules/$1" ] ; then
  echo "No modules directory named $1"
  exit 1
fi

if [[ "$KERNEL_VERSION" == *-lts ]]; then
    if [ -n $ROOTDIR ]; then
        INITRAMFS_FILE=$ROOTDIR/initramfs-lts
    else
        INITRAMFS_FILE=/boot/initramfs-lts
    fi
else
    if [ -n $ROOTDIR ]; then
        INITRAMFS_FILE=$ROOTDIR/initramfs
    else
        INITRAMFS_FILE=/boot/initramfs
    fi
fi

printf "  creating $INITRAMFS_FILE... "

binfiles="sh blkid dmsetup killall ls losetup lvm mkdir mknod mount umount udevd udevadm switch_root"

unsorted=$(mktemp /tmp/unsorted.XXXXXXXXXX)

DATDIR=/share/mkinitramfs

# Create a temporary working directory
WDIR=$(mktemp -d /tmp/initrd-work.XXXXXXXXXX)

# Create base directory structure
mkdir -p $WDIR/{bin,dev,lib/firmware,run,sys,proc}
mkdir -p $WDIR/etc/udev/rules.d

# Create necessary device nodes
mknod -m 640 $WDIR/dev/console c 5 1
mknod -m 664 $WDIR/dev/null    c 1 3

# Install the udev configuration files
if [ -f /etc/udev/udev.conf ]; then
  cp /etc/udev/udev.conf $WDIR/etc/udev/udev.conf
fi

for file in $(find /etc/udev/rules.d/ -type f) ; do
  cp $file $WDIR/etc/udev/rules.d
done

# lib64 symlink required if not on musl
if [ ! -f  /lib/ld-musl-x86_64.so.1 ]; then
  ln -s lib $WDIR/lib64
fi

# Install any firmware present
#cp -a /lib/firmware $WDIR/lib

# Install the init file
install -m0755 $DATDIR/init $WDIR/init

if [  -n "$KERNEL_VERSION" ] ; then
  if [ -x /bin/kmod ] ; then
    binfiles="$binfiles kmod"
  fi
fi

# Install basic binaries
for f in $binfiles ; do
  ldd /bin/$f 2>/dev/null | sed "s/\t//" | cut -d " " -f1 >> $unsorted
  copy $f bin
done

# Add module symlinks if appropriate
if [ -n "$KERNEL_VERSION" ] && [ -x /bin/kmod ] ; then
  ln -s kmod $WDIR/bin/lsmod
  ln -s kmod $WDIR/bin/insmod
  ln -s kmod $WDIR/bin/modprobe
fi

# Add lvm symlinks if appropriate
# Also copy the lvm.conf file
if  [ -x /bin/lvm ] ; then
  ln -s lvm $WDIR/bin/lvchange
  ln -s lvm $WDIR/bin/lvrename
  ln -s lvm $WDIR/bin/lvextend
  ln -s lvm $WDIR/bin/lvcreate
  ln -s lvm $WDIR/bin/lvdisplay
  ln -s lvm $WDIR/bin/lvscan

  ln -s lvm $WDIR/bin/pvchange
  ln -s lvm $WDIR/bin/pvck
  ln -s lvm $WDIR/bin/pvcreate
  ln -s lvm $WDIR/bin/pvdisplay
  ln -s lvm $WDIR/bin/pvscan

  ln -s lvm $WDIR/bin/vgchange
  ln -s lvm $WDIR/bin/vgcreate
  ln -s lvm $WDIR/bin/vgscan
  ln -s lvm $WDIR/bin/vgrename
  ln -s lvm $WDIR/bin/vgck
  # Conf file(s)
  cp -a /etc/lvm $WDIR/etc
fi

# Install libraries
sort $unsorted | uniq | while read library ; do
  copy $library lib
done

if [ -d /lib/udev ]; then
  cp -a /lib/udev $WDIR/lib
fi

# Install the kernel modules if requested
if [ -n "$KERNEL_VERSION" ]; then
  find                                                                        \
     /lib/modules/$KERNEL_VERSION/kernel/{crypto,fs,lib}                      \
     /lib/modules/$KERNEL_VERSION/kernel/drivers/{block,ata,md,firewire}      \
     /lib/modules/$KERNEL_VERSION/kernel/drivers/{scsi,message,pcmcia,virtio} \
     /lib/modules/$KERNEL_VERSION/kernel/drivers/usb/{host,storage}           \
     -type f 2>/dev/null | cpio --make-directories -p --quiet $WDIR

  cp /lib/modules/$KERNEL_VERSION/modules.{builtin,order}                     \
            $WDIR/lib/modules/$KERNEL_VERSION

  depmod -b $WDIR $KERNEL_VERSION
fi

( cd $WDIR ; find . | cpio -o -H newc --quiet | gzip -9 ) > $INITRAMFS_FILE

# Remove the temporary directory and file
rm -rf $WDIR $unsorted
printf "done\n"
