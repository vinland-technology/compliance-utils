#!/bin/bash

LIB=$1
TMP_DIR=~/.vinland-compliance-utils/plot-package
FORMATS="pdf jpg png"

LIB_NAME=$(basename $LIB)

create_dot()
{

    DEPS=$(readelf -d $LIB | grep NEEDED | cut -d ":" -f 2 | sed -e 's,^[ ]*\[,,g' -e 's,\]$,,g' | sort -u | grep -v -e GLIBC -e libpthread -e librt -e libc.so -e libdl)
    printf "digraph depends {\n  node [shape=plaintext]"
    for dep in $DEPS
    do
        echo "\"$LIB_NAME\" -> \"$dep\""
    done
    echo "}"
}

create_dot > $LIB_NAME.dot


for format in $FORMATS
do
    dot -T$format -O "$LIB_NAME.dot" &&  echo "Created $LIB_NAME.dot.$format"
done




