#!/bin/bash

for i in $@; do
    case "$i" in
        -h|--help)
            echo "usage: `basename $0` <rootdir>"
            exit 0;;
    esac
done

if [ -z "$1" ]; then $0 -h; exit 0; fi

setup-chroot -m $1
chroot $1 /bin/sh
setup-chroot -u $1
