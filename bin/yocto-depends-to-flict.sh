#!/bin/bash


# THIS SCRIPT IS FROM NOW ON OBSLETE (2020-11-24)

# default
TMP_DIR=~/.vinland-compliance-utils/plot-package
LIBC="false"
DEBUG=trues

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

while [ "$1" != "" ]
do
    case "$1" in
        "--depends-file" | "-df")
#            echo "USING $2 as dep file"
            DOT_FILE_NAME="$2"
            shift
            ;;
        "--license-manifest" | "-lm")
            LICENSE_MANIFEST="$2"
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

#echo LICENSE_MANIFEST: $LICENSE_MANIFEST
DOT_FILE="$DOT_FILE_NAME"
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

if [ "$LICENSE_MANIFEST" = "" ] | [ ! -f $LICENSE_MANIFEST ] 
then
    err "No license manifest file (\"$LICENSE_MANIFEST\") found"
    exit 2
fi

find_license()
{
    local PKG="$1"

    echo grep "$PKG" $LICENSE_MANIFEST 
}

package_to_json_helper()
{
    local PKG="$1"
    grep "^\"$PKG\"" "$DOT_FILE" | grep -v "\.so" | grep -v "\-lic\"" | sed 's,\[label=\"[a-zA-Z0-9+\>\=. ]*\"\],,g' | sed 's,\[style=dotted\],,g' | sort -u | cut -d ">" -f 2 | sed -e 's,^[ ]*\",,g' -e 's,\"[ ]*$,,g' | grep -v -e '/bin\/sh' | grep -v "\-lic\"" 
}

package_to_json()
{
    local PKG="$1"
    local INDENT="$2"

    find_license $PKG
#    local license=$(find_license $PKG)

    echo "$INDENT{"
    echo "$INDENT  \"name\": \"$PKG\","
    echo "$INDENT \"license\": \"unknown\","
    echo "$INDENT  \"dependencies\": ["
    if [ "$LIBC" = "false" ]
    then
        PKGS=$(package_to_json_helper "$PKG" \
            | grep -v -e GLIBC -e libpthread -e librt -e libc.so -e libdl \
                   -e libc6 -e rtld -e \"/bin/sh\")
    else
        PKGS=$(package_to_json_helper "$PKG")
    fi


    
    local cnt=0
    for pkg in $PKGS
    do
        if [ $cnt -ne 0 ]
        then
            echo ","
        fi
        cnt=$(( $cnt + 1 ))
        debug "$INDENT $PKG -> $pkg"
        package_to_json "$pkg" "$INDENT  "
#        sleep 0.1
    done
    echo "$INDENT  ]"
    echo "$INDENT}"
}


echo "{"
echo "  \"component\": "
package_to_json $PKG "  "
echo "}"
