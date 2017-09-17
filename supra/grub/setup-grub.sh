#!/bin/mksh

if [ $# -eq 0 ]; then echo "try $0 <boot-directory> <device>"; exit 1; fi

grub-install --modules=part_msdos \
             --target=i386-pc \
             --boot-directory=$1 $2
