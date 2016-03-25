#!/bin/sh

set -e

distributor=$(lsb_release -is)
release=$(lsb_release -rs)
codename=$(lsb_release -cs)

echo "    \"OS Distributor\": \"$distributor\"," >> $1
echo "    \"OS Release\": \"$release\"," >> $1
echo "    \"OS CodeName\": \"$codename\"," >> $1
