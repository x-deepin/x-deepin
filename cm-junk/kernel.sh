#!/bin/sh

set -e

release=$(uname -r)
version=$(uname -v | sed -ne 's,^.*\ \([0-9]\+[0-9\.\-]\+\)\ .*$,\1,p')
arch=$(uname -m)
cmdline=$(cat /proc/cmdline)
echo "    \"Kernel Release\": \"$release\"," >> $1
echo "    \"Kernel Version\": \"$version\"," >> $1
echo "    \"Architecture\": \"$arch\"," >> $1
echo -n "    \"Kernel cmdline\": [" >> $1
prev=""
for word in $cmdline; do
    if [ -n "$prev" ]; then
        echo -n ", " >> $1
    fi
    param=$(echo $word | sed 's,^BOOT_IMAGE=.*,,g' | sed 's,^root=.*,,g')
    if [ -n "$param" ]; then
        echo -n "\"$param\"" >> $1
    fi
    prev=$param
done
echo "]," >> $1
