#!/bin/sh

set -e

d=$(dirname $0)
$d/Xversion.sh $1
$d/xfs.sh $1
$d/Xorg-video.sh $1
