#!/bin/sh

mount -t proc proc /proc -o nosuid,noexec,nodev
mount -t sysfs sys /sys -o nosuid,noexec,nodev

mount -t devtmpfs dev /dev -o mode=0755,nosuid
mkdir -p /dev/pts /dev/shm

mount -t devpts devpts /dev/pts -o mode=0620,gid=2,nosuid,noexec

mount -t tmpfs run /run -o mode=0755,nosuid,nodev
mount -t tmpfs shm /dev/shm -o mode=1777,nosuid,nodev

udevadm info --cleanup-db
udevd --daemon

udevadm trigger --action=add --type=subsystems
udevadm trigger --action=add --type=devices
udevadm settle --timeout=120

mount -a
mount -o remount,rw /

ln -sf /proc/mounts /cfg/mtab

hostname -b -F /cfg/hostname

export TZ="Europe/Stockholm"
hwclock -s -u
unset TZ

respawn agetty --noclear 38400 tty1 linux &
respawn agetty --noclear 38400 tty2 linux &
respawn agetty --noclear 38400 tty3 linux &
respawn agetty --noclear 38400 tty4 linux &
respawn agetty --noclear 38400 tty5 linux &
respawn agetty --noclear 38400 tty6 linux &
