#!/bin/sh

set -e
export LANG=C
export PATH=$PATH:/sbin:/usr/sbin
export DISPLAY=:0

distributor=$(lsb_release -i -s)

case $distributor in
Debian|Deepin)
    sudo apt-get --yes install hwinfo lsof dmidecode lsb-release apt-file pciutils kmod coreutils
    sudo apt-file update
    ;;
SuSE)
    sudo zypper install hwinfo lsof dmidecode lsb-release pciutils kmod coreutils
    ;;
Redhat)
    sudo yum install hwinfo lsof dmidecode lsb-release pciutils kmod coreutils
    ;;
esac

d=`dirname $0`
echo "[" > $1
$d/netcard.sh $1
$d/video-card.sh $1 netcard
echo " }" >> $1
echo "]" >> $1
