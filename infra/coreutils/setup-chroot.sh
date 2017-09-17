#!/bin/bash

MountChroot() {
    for d in dev/pts proc run sys src/rcp pkg/arc; do
        if [ ! -d $rootdir/$d ]; then mkdir -p $rootdir/$d; fi
    done

    if [ -f $rootdir/etc/resolv.conf ]; then
        mount -o bind /etc/resolv.conf $rootdir/etc/resolv.conf
    fi

    for i in /dev /dev/pts /proc /run /sys /src/rcp /pkg/arc; do
        mount -o bind $i ${rootdir}${i}
    done
}

UnMountChroot() {
    conf=$rootdir/etc/resolv.conf

    if grep -qs $conf /proc/mounts; then
        umount -v $conf
    fi

    for i in /dev/pts /dev /proc /sys /run /src/rcp /pkg/arc; do
        umount -v ${rootdir}${i}
    done
}

for i in $@; do
    case "$i" in
        -h|--help)
            echo "usage: `basename $0` [operation] <rootdir>"
            echo "operation:"
            echo "  -m, --mount     mount chroot environment"
            echo "  -u, --umount    unmount chroot environment"
            exit 0;;
        -m|--mount) rootdir=$(cd $2; pwd); MountChroot;;
        -u|--umount) rootdir=$(cd $2; pwd); UnMountChroot;;
    esac
done

if [ -z "$1" ]; then $0 -h; exit 0; fi
