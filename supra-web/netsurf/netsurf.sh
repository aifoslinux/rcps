#!/bin/sh
shortname=$(echo $LANG | cut -b1-2)
if [ -d /share/netsurf/$shortname ]; then
	/bin/netsurf-gtk3 "$@"
else
	LANG=en_US /bin/netsurf-gtk3 "$@"
fi
