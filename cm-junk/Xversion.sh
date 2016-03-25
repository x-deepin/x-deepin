#!/bin/sh

set -e

Xorg -version > xver.tmp 2>&1 || /usr/lib/xorg/Xorg -version > xver.tmp 2>&1

version=$(cat xver.tmp | sed -ne 's,^xorg-server.*:\([0-9]\+[0-9\.\-]\+\)\ .*$,\1,p')
echo "    \"Xorg Version\": \"$version\"," >> $1
