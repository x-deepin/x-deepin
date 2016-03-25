#!/bin/sh

set -e

drvfile=$(modinfo xfs | sed -ne 's,^filename:[\ \t]*,,p')
drvversion=$(modinfo xfs | sed -ne 's,^version:[\ \t]*,,p')

if test "x$drvversion" = "x"; then
	drvversion=$(sha256sum -b $drvfile | awk '//{print $1}')
fi
checksum=$(sha256sum -b $drvfile | awk '//{print $1}')

echo "    \"XFS Driver File\": \"$drvfile\"," >> $1
echo "    \"XFS Driver Version\": \"$drvversion\"," >> $1
echo "    \"XFS sha256sum\": \"$checksum\"," >> $1

sha256sum -b $drvfile >> checksum.txt
sort -u checksum.txt > tmp.txt
mv tmp.txt checksum.txt
