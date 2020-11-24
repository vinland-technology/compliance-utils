#!/bin/bash

# SPDX-FileCopyrightText: 2020 Henrik Sandklef
#
# SPDX-License-Identifier: GPL-3.0-or-later

# default
DOT_FILE_NAME="depends.dot"
TMP_DIR=~/.vinland/compliance-utils/plot-package
RECURSIVE=false

FORMATS=png
export LIBC=false
PACKAGE_NAME=false

err()
{
    echo "$*" 1>&2
}

debug()
{
    if [ "$DEBUG" = "true" ]
    then
        echo "$*" 1>&2
    fi
}

exit_if_error()
{
    if [ $1 -ne 0 ]
    then
        if [ "$2" != "" ]
        then
            err $2
        fi
        exit 3
    fi
}



usage()
{
    echo "NAME"
    echo "    $(basename $0) - plot dependecy graph in misc formats"
    echo 
    echo "SYNOPSIS"
    echo "    $(basename $0) [OPTIONS] package"
    echo
    echo "DESCRIPTION"
    echo "    Plots (in misc formats) a graphical view of a package, as found in a depends.dot"
    echo "    file as produced by Yocto"
    echo
    echo "OPTIONS"
    echo
    echo "    -df, --depends-file <FILE> "
    echo "        Use FILE as dependecy file. Default: depends.dot"
    echo 
    echo "    -pdf"
    echo "        Produce pdf graph"
    echo 
    echo "    -jpg"
    echo "        Produce jpg graph"
    echo "    -td, --tmp-dir <DIR>"
    echo "        Use DIR as tmp dir. Default is ~/.vinland-compliance-utils/plot-package"
    echo
    echo "    -nl, --no-libc"
    echo "        Exclude libc libraries"
    echo
    echo "    -pn, --package-name"
    echo "        Use package names instead of libraries"
    echo
    echo "    -r, --recursive"
    echo "        Prints dependencies recursively. Automatically turns on package names (-pn)"
    echo
    echo "    -s, --search"
    echo "        Search for package(s), matching package name, instead of creating graph"
    echo
    echo "    -h, --help"
    echo "        Prints this help text"
    echo
    echo "EXIT CODES"
    echo
    echo "    0    if OK"
    echo "    1    no dependency file could be found"
    echo "    2    no package specified"
    echo "    3    something else, see error message"
    echo
}

while [ "$1" != "" ]
do
    case "$1" in
        "--depends-file" | "-df")
#            echo "USING $2 as dep file"
            DOT_FILE_NAME="$2"
            shift
            ;;
        "-pdf")
            FORMATS=" $FORMATS pdf "
            ;;
        "-jpg")
            FORMATS=" $FORMATS jpg "
            ;;
        "--tmp-dir" | "-td")
            TMP_DIR="$2"
            shift
            ;;
        "--help" | "-h")
            usage
            exit 0
            ;;
        "--libc" | "-l")
            LIBC=true
            ;;
        "--package-name" | "-pn")
            PACKAGE_NAME=true
            ;;
        "--search" | "-s")
            SEARCH=true
            ;;
        "--recursive" | "-r")
            RECURSIVE=true
            PACKAGE_NAME=true
            ;;
        *)
            # assume package
            PKG="$1"
    esac
    shift
done

DOT_FILE="$DOT_FILE_NAME"
PKG_DOT_FILE="$TMP_DIR/${PKG}.dot"
mkdir -p $TMP_DIR

if [ "$PKG" = "" ]
then
    err "No package specified"
    exit 2
fi

if [ "$DOT_FILE_NAME" = "" ] | [ ! -f $DOT_FILE_NAME ] 
then
    err "No dependency file (\"$DOT_FILE_NAME\") found"
    exit 1
fi

if [ "$RECURSIVE" = "true" ] && [ "$PACKAGE_NAME" != "true" ]
then
    err "When using recursive mode you must use package names (-pn)"
fi
    


create_dot_helper()
{
    local PKG="$1"
    if [ "$PACKAGE_NAME" = "true" ]
    then
        grep "^\"$PKG\"" "$DOT_FILE" | grep -v "\.so" | grep -v "\-lic\"" | sed 's,\[label=\"[a-zA-Z0-9+\>\=. ]*\"\],,g' | sed 's,\[style=dotted\],,g' | sort -u 
    else
        grep "^\"$PKG\"" "$DOT_FILE" | grep "\.so" | sed 's,([0-9A-Za-z_]*),,g' | sed 's,\[style=dotted\],,g' | sort -u 
    fi
}

create_dot_package()
{
    local PKG="$1"
    if [ "$RECURSIVE" = "true" ]
    then
        if [ "$LIBC" = "false" ]
        then
            PKGS=$(create_dot_helper $PKG | grep -v -e GLIBC -e libpthread -e librt -e libc.so -e libdl -e libc6\" -e \"rtld -e \"/bin/sh\" | tr '\n' '#')
        else
            PKGS=$(create_dot_helper $PKG | tr '\n' '#')
        fi
   #     echo askhsakjdh : $PKGS
        echo $PKGS |  tr '#' '\n' | grep -v "^[ ]*$" | while read DEP_LINE
        do
            echo "$DEP_LINE"
            DEP=$(echo $DEP_LINE | cut -d ">" -f 2 | sed -e 's,^[ ]*\",,g' -e 's,\"[ ]*$,,g' )
 #           echo "new dep: \"$DEP_LINE\" ===> \"$DEP\""
  #          echo create_dot_package "$DEP"
            create_dot_package "$DEP"
        done
    else
        if [ "$LIBC" = "false" ]
        then
            create_dot_helper "$PKG" | grep -v -e GLIBC -e libpthread -e librt -e libc.so -e libdl -e libc6\" -e \"rtld -e \"/bin/sh\"
        else
            create_dot_helper "$PKG"
        fi
    fi

}

create_dot()
{
    head -2 "$DOT_FILE"
    exit_if_error $?

    create_dot_package "$1" | sort -u
    exit_if_error $?

    tail -1 "$DOT_FILE"
    exit_if_error $?
}

create_format()
{
    FMT=$1
    FMT_FILE=$(basename $PKG_DOT_FILE | sed "s,\.dot$,\.${FMT},g")
    dot -T$FMT "$PKG_DOT_FILE" > ${FMT_FILE} &&  echo "Created $FMT_FILE (from $PKG_DOT_FILE)"
    exit_if_error $? "Failed creating $FMT_FILE (from $PKG_DOT_FILE)"
}

verify_dot_file()
{
    local DOT_FILE=$1
    local PACKAGE=$2
    if [ $(wc -l ${DOT_FILE} | awk ' { print $1}') -le 3 ]
    then
        err "Could not create dot file for package: $PACKAGE"
        exit 3
    fi
}

if [ "$SEARCH" = "true" ]
then
    echo -n "Searching for $PKG in $DOT_FILE:"
    HITS=$(cat ${DOT_FILE} | awk ' { print $1 }' | sed 's,\",,g'  | grep "$PKG" | grep -v "\-lic\"" | sed 's,\[label=\"[a-zA-Z0-9+\>\=. ]*\"\],,g' | sed 's,\[style=dotted\],,g' | sort -u )
    if [ "$HITS" = "" ]
    then
        echo " nothing found"
    else
        echo
        for hit in $HITS
        do
            echo " * $hit"
        done
    fi
    exit 0
fi

create_dot "$PKG"  > $PKG_DOT_FILE

verify_dot_file $PKG_DOT_FILE $PKG

for format in $FORMATS
do
    create_format $format
done

