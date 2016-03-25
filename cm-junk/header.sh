#!/bin/sh

set -e

d=$(dirname $0)
echo " {" >> $1
$d/os-version.sh $1
$d/kernel.sh $1
$d/machine-type.sh $1
$d/machine-id.sh $1
# $d/Xversion.sh $1
# $d/xfs.sh $1
# $d/Xorg-video.sh $1
