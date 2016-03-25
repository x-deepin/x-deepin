#!/bin/sh

set -e

manufac=$(sudo dmidecode --string system-manufacturer)
product=$(sudo dmidecode --string system-product-name | sed -ne 's,\(^.*[0-9a-zA-Z]\).*$,\1,p')

echo "    \"Manufacturer\": \"$manufac\"," >> $1
echo "    \"Product Name\": \"$product\"," >> $1
