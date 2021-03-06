#!/bin/sh

export PATH=/bin

problem()
{
   printf "Encountered a problem!\n\nDropping you to a shell.\n\n"
   sh
}

no_device()
{
   printf "The device %s, which is supposed to contain the\n" $1
   printf "root file system, does not exist.\n"
   printf "Please fix this problem and exit this shell.\n\n"
}

no_mount()
{
   printf "Could not mount device %s\n" $1
   printf "Sleeping forever. Please reboot and fix the kernel command line.\n\n"
   printf "Maybe the device is formatted with an unsupported file system?\n\n"
   printf "Or maybe filesystem type autodetection went wrong, in which case\n"
   printf "you should add the rootfstype=... parameter to the kernel command line.\n\n"
   printf "Available partitions:\n"
}

do_mount_live()
{
   mount -n -t tmpfs none /.root

   mkdir /.{temp,live}
   mkdir /.root/{up,wrk}

   modprobe isofs
   modprobe loop
   modprobe overlay
   modprobe squashfs

   eval $root
   mount -o loop /dev/disk/by-label/$CDLABEL /.temp

   if ! mount -n -t squashfs /.temp/LiveOS/rootfs.sfs /.live; then
       problem
   fi

   olay_args="rw,lowerdir=/.live,upperdir=/.root/up,workdir=/.root/wrk"

   if ! mount -n -t overlay overlay -o "$olay_args" /.root; then
       problem
   else
       echo "Successfully mounted device $root"
   fi
}

do_mount_root()
{
   case "$root" in
       /dev/*   ) device=$root ;;
       UUID=*   ) eval $root; device="/dev/disk/by-uuid/$UUID"  ;;
       LABEL=*  ) eval $root; device="/dev/disk/by-label/$LABEL" ;;
       ""       ) echo "No root device specified." ; problem    ;;
   esac

   while [ ! -b "$device" ] ; do
       no_device $device
       problem
   done

   if ! mount -n -t "$rootfstype" -o "$rootflags" "$device" /.root ; then
       no_mount $device
       cat /proc/partitions
       while true ; do sleep 10000 ; done
   else
       echo "Successfully mounted device $root"
   fi
}

init=/bin/init
root=
rootdelay=
rootfstype=auto
ro="ro"
rootflags=
device=

mount -n -t devtmpfs devtmpfs /dev
mount -n -t proc     proc     /proc
mount -n -t sysfs    sysfs    /sys
mount -n -t tmpfs    tmpfs    /run

read -r cmdline < /proc/cmdline

for param in $cmdline ; do
  case $param in
    init=*      ) init=${param#init=}             ;;
    root=*      ) root=${param#root=}             ;;
    rootdelay=* ) rootdelay=${param#rootdelay=}   ;;
    rootfstype=*) rootfstype=${param#rootfstype=} ;;
    rootflags=* ) rootflags=${param#rootflags=}   ;;
    ro          ) ro="ro"                         ;;
    rw          ) ro="rw"                         ;;
  esac
done

udevd --daemon --resolve-names=never
udevadm trigger
udevadm settle

if [ -x /bin/vgchange  ] ; then /bin/vgchange -a y > /dev/null ; fi
if [ -n "$rootdelay"    ] ; then sleep "$rootdelay"              ; fi

mkdir /.root
[ -n "$rootflags" ] && rootflags="$rootflags,"
rootflags="$rootflags$ro"

case "$root" in
    CDLABEL=*) do_mount_live ;;
    *        ) do_mount_root ;;
esac

killall -w udevd

exec switch_root /.root "$init" "$@"
