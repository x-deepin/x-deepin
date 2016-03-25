#!/bin/sh

set -e

d=$(dirname $0)

bins=$(which hwinfo || :)
if test "x$bins" = "x"; then
	echo "Please install hwinfo package."
	exit 1
fi

bins=$(which sha256sum || :)
if test "x$bins" = "x"; then
	echo "Please install coreutils package."
	exit 1
fi

bins=$(which lsb_release || :)
if test "x$bins" = "x"; then
	echo "Please install lsb-release package."
	exit 1
fi

devices=$(hwinfo --netcard | sed -ne 's,Device File:,,p')
distributor=$(lsb_release -i -s)

case $distributor in
Debian)
	bins=$(which apt-file || :)
	if test "x$bins" = "x"; then
		echo "Please install apt-file."
		exit 1
	fi
	;;
Suse|Redhat)
	bins=$(which rpm || :)
	if test "x$bins" = "x"; then
		echo "Please install rpm."
		exit 1
	fi
	;;
esac

if [ $# -eq 2 ]; then
	prev=$2
else
	prev=""
fi

collect_one() {
    dev=$2
    distributor=$(lsb_release -i -s)
	vendor=$(hwinfo --netcard --only $dev | sed -ne 's,^\ *Vendor:\ \(.*\)\ \"[^$].*$,\1,p')
	device=$(hwinfo --netcard --only $dev | sed -ne 's,^\ *Device:\ \(.*\)\ \"[^$].*$,\1,p')
	subvendor=$(hwinfo --netcard --only $dev | sed -ne 's,^\ *SubVendor:\ \(.*\)\ \"[^$].*$,\1,p')
	subdevice=$(hwinfo --netcard --only $dev | sed -ne 's,^\ *SubDevice:\ \(.*\)\ \"[^$].*$,\1,p')
	revision=$(hwinfo --netcard --only $dev | sed -ne 's,^\ *Revision:\ ,,p')
	driver=$(hwinfo --netcard --only $dev | sed -ne 's,^\ *Driver:\ \"\(.*\)\"$,\1,p')
	drvfile=$(echo $driver | xargs modinfo | sed -ne 's,^filename:\ *,,p')
	drvversion=$(echo $driver | xargs modinfo | sed -ne 's,^version:\ *,,p')
	if test "x$drvversion" = "x"; then
		drvversion=$(sha256sum -b $drvfile | awk '//{print $1}')
	fi
    checksum=$(sha256sum -b $drvfile | awk '//{print $1}')

	case $distributor in
	Debian)
		pkg=$(apt-file search $drvfile | grep " $drvfile" | sed -ne 's,\(^.*\):.*$,\1,p')
		;;
	Suse|Redhat)
		pkg=$(rpm -qf $drvfile | sed -ne 's,\(^.*\):.*$,\1,p')
		;;
	*)
		echo "Unknown Distribution"
		;;
	esac

# need to add module parameter here
	param=$(grep -ir "^options \+$driver" /etc/modprobe.d/* ./test.conf | sed 's,^.*options\ \+[0-9a-zA-Z]*\ \+,,g')

    answer=""
	hwinfo --netcard --only $dev
	while test "x$answer" = "x" -o "x$tmp" != "x" || 
		[ $answer -lt -100 -o  $answer -gt 100 ]; do
		read -p "Please score the driver.(rang: -100 - 100, -100 totally not work, 100 fully functional)" answer
		tmp=$(echo $answer | sed 's,^-,,g' | sed 's,[0-9]\+,,g')
		if [ "x$tmp" != "x" ]; then
			echo "Not a number, Please enter a number."
		elif [ $answer -lt -100 -o $answer -gt 100 ]; then
			echo "Please enter a number between -100 - 100"
		fi
	done

	$d/header.sh $1

	echo "    \"DevClass\": \"netcard\"," >> $1
	echo "    \"Vendor\": \"$vendor\"," >> $1
	echo "    \"Device\": \"$device\"," >> $1
	echo "    \"SubVendor\": \"$subvendor\"," >> $1
	echo "    \"SubDevice\": \"$subdevice\"," >> $1
	echo "    \"Revision\": \"$revision\"," >> $1
	echo "    \"Driver\": \"$driver\"," >> $1

    echo -n "    \"Module Parameters\": [" >> $1
    prev1=""
    for p in $param; do
        if [ -n "$prev1" ]; then
            echo -n ", " >> $1
        fi
        echo -n "\"$p\"" >> $1
        prev1=$p
    done
    echo "]," >> $1

	echo "    \"Driver File\": \"$drvfile\"," >> $1
	echo "    \"Driver Version\": \"$drvversion\"," >> $1
    echo "    \"sha256sum\": \"$checksum\"," >> $1
	echo "    \"Package\": \"${pkg:-Unknown Package}\"," >> $1
	echo "    \"Score\": \"$answer\"" >> $1

	sha256sum -b $drvfile >> checksum.txt
	sort -u checksum.txt > tmp.txt
	mv tmp.txt checksum.txt
}

for dev in $devices; do
	if [ -n "$prev" ]; then
		echo " }," >> $1
	fi

    collect_one $1 $dev

	prev=$dev
done
