#!/bin/sh

macaddr=$(ip a | grep "link\/" | awk '//{print $2}')
serialnum=$(sudo dmidecode --string system-serial-number)
src="$macaddr $serialnum"
id=$(echo $src | sha256sum -b | awk '//{print $1}')

echo "    \"Machine ID\": \"$id\"," >> $1
