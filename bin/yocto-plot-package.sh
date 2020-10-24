#!/bin/bash

# default
DOT_FILE_NAME="depends.dot"
TMP_DIR=~/.vinland-compliance-utils/plot-package

FORMATS=png

usage()
{
    echo "usage text coming soon"
}

while [ "$1" != "" ]
do
    case "$1" in
        "--depends-file" | "-df")
            DOT_FILE_NAME="$2"
            shift
            ;;
        "-pdf")
            FORMATS=" $FORMATS pdf "
            shift
            ;;
        "--tmp-dir" | "-td")
            TMP_DIR="$2"
            shift
            ;;
        "--help" | "-h")
            usage
            exit 0
            ;;
        *)
            # assume package
            PKG="$1"
    esac
    shift
done

DOT_FILE="$(dirname $(realpath $0))/resources/$DOT_FILE_NAME"
PKG_DOT_FILE="$TMP_DIR/${PKG}.dot"
mkdir -p $TMP_DIR

if [ "$PKG" = "" ]
then
    echo "No package specified"
    exit 1
fi

if [ "$DOT_FILE_NAME" = "" ] | [ ! -f $DOT_FILE_NAME ] 
then
    echo "No depends.dot found (\"$DOT_FILE_NAME\")"
    exit 1
fi

create_dot()
{
    head -2 "$DOT_FILE"
    grep "$PKG" "$DOT_FILE"
    tail -1 "$DOT_FILE"
}

create_format()
{
    dot -T$1 -O "$PKG_DOT_FILE" &&  echo "Created $PKG_DOT_FILE.$1"

}

create_dot > $PKG_DOT_FILE

for format in $FORMATS
do
    create_format $format
done

