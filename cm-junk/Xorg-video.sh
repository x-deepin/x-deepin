#!/bin/sh

set -e

pid=$(ps -C Xorg | awk '/Xorg/{print $1}')
distributor=$(lsb_release -i -s)
drivers=$(sudo lsof -c Xorg | awk '/drivers/{print $9}')

if [ -z "$drivers" ]; then
    drivers=$(sudo lsof -c Xorg | awk '/\/nvidia\/|libnvidia/{print $9}')
fi

echo "    \"Xorg Video Driver\": [" >> $1
prev=""

for drv in $drivers; do
	case $distributor in
	Debian)
		pkg=$(apt-file search $drv | grep " $drv" | sed -ne 's,\(^.*\):.*$,\1,p')
		if test "x$pkg" != "x"; then
			version=$(aptitude show $pkg | sed -ne 's,^Version:\ ,,p')
		fi
		;;
	Suse|Redhat)
		pkg=$(rpm -qf $drv | sed -ne 's,\(^.*\):.*$,\1,p')
		if test "x$pkg" != "x"; then
			version=$(rpm -qi $pkg | sed -ne 's,^Version:\ ,,p')
		fi
		;;
	*)
		echo "Unknown Distribution."
		;;
	esac

	checksum=$(sha256sum -b $drv | awk '//{print $1}')
	if test "x$version" = "x"; then
		version=$(sha256sum -b $drv | awk '//{print $1}')
	fi
	if [ -n "$prev" ]; then
		echo "                          }," >> $1
	fi
	echo "                          {" >> $1
	echo "                           \"Driver File\": \"$drv\"," >> $1
	echo "                           \"Driver Package\": \"${pkg:-Unknown Package}\"," >> $1
	echo "                           \"Driver Version\": \"$version\"," >> $1
	echo "                           \"sha256sum\": \"$checksum\"" >> $1

	prev=$drv

	sha256sum -b $drv >> checksum.txt
	sort -u checksum.txt > tmp.txt
	mv tmp.txt checksum.txt
done

if [ -n "$prev" ]; then
	echo "                          }" >> $1
fi
echo "                         ]," >> $1
