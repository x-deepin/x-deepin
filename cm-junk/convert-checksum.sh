#!/bin/sh

set -e

csfile="checksum.txt"
vfile="vfile.json"
vers=$(cat $csfile | awk '//{print $1}')

echo "[" > $vfile

prev=""

for ver in $vers; do
    if [ -n "$prev" ]; then
        echo "  }," >> $vfile
    fi
    version=$(grep $ver $csfile | awk '//{print $1}')
    url=$(grep $ver $csfile | awk '//{print $2}' | sed 's,\*,,g')
    echo "  {" >> $vfile
    echo "    \"sha256sum\": \"$version\"," >> $vfile
    echo "    \"File URL\": \"$url\"" >> $vfile
    prev=$ver
done

echo "  }" >> $vfile
echo "]" >> $vfile
