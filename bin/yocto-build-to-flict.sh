#!/bin/bash

# default
TMP_DIR=~/.vinland-compliance-utils/plot-package
LIBC="false"
DEBUG=true
BUILD_DIR=./tmp/work/core2-64-poky-linux

LIBC_EXCLUDE=" -e GLIBC -e libpthread -e librt -e libc.so -e libdl -e libc6 -e rtld -e \"/bin/sh\" -e libc\.so -e ld-linux -e libm\.so" 
NONSENSE_EXCLUDE=" -e _z_z_z_z_z_z_z_z_z"

LIBC=true

EXCLUDES="-e \.debug -e pkgconfig "

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

debugn()
{
    if [ "$DEBUG" = "true" ]
    then
        echo -n "$*" 1>&2
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
        "--build-dir" | "-td")
            BUILD_DIR="$2"
            shift
            ;;
        "--tmp-dir" | "-td")
            TMP_DIR="$2"
            shift
            ;;
        "--no-libc" | "-nl")
            LIBC=false
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



if [ "$PKG" = "" ]
then
    err "No package specified"
    exit 2
fi

if [ "$LIBC" = "true" ]
then
    LIB_EXCLUDE=$LIBC_EXCLUDE
else
    LIB_EXCLUDE=$NONSENSE_EXCLUDE    
fi




find_lib()
{
    local LIB="$1"
    LIB_PATH=$(find $BUILD_DIR/*/*/packages-split/*/usr/lib/ \
                    -name "${LIB}*" -type f | \
                   grep -v $EXCLUDES)
    if [ "$LIB_PATH" != "" ]
    then
        echo $LIB_PATH
        return
    fi
    LIB_PATH=$(find $BUILD_DIR/*/*/packages-split/*/lib/ \
                    -name "${LIB}*" -type f | \
                   grep -v $EXCLUDES)
    if [ "$LIB_PATH" != "" ]
    then
        echo $LIB_PATH
        return
    fi
}

find_package_dir()
{
    local PKG="$1"
    find $BUILD_DIR/$PKG/*/packages-split/ -type d -prune
}

find_package_dirs()
{
    local PKG="$1"
    local DIR="$2"
    find $DIR/* -type d -prune | grep -v "${PKG}-lic$"
}

print_package_sub_dir()
{
    local PKG="$1"
    local DIR="$2"
    local COMP=$(basename $DIR)

    find $DIR/*/lib $DIR/*/usr/lib $DIR/*/bin $DIR/*/usr/bin -type f  \
         2>/dev/null  | \
        grep -v $EXCLUDES
}

print_artefact()
{
    local PKG="$1"
    local DIR="$2"
    local ART="$3"
    local INDENT="$4"

    if [ -h "$ART" ]
    then
        debug "$ART: symbolic link, ignoring"
        return
    fi
    if [ "$ART" = "" ]
    then
 #       debug "$ART: empty name"
        return
    fi
    
#    echo "check type of \"$ART\""
    TYPE=$(file -b $ART)
 #   echo " - type $TYPE "
    if [[ "${TYPE}" =~ "POSIX shell script" ]]
    then
        echo "script"
    elif [[ "${TYPE}" =~ "LSB shared object" ]]
    then
        echo "$INDENT {"
        echo "$INDENT   \"name\": \"$(basename $ART)\","
        echo "$INDENT   \"license\": \"unknown\","
        echo -n "$INDENT   \"dependencies\": ["

        #
        # dependencies
        #
        DEPS=$(readelf -d $ART | grep NEEDED | cut -d ":" -f 2 | \
                   sed -e 's,^[ ]*\[,,g' -e 's,\]$,,g' | \
                   grep -v $LIBC_EXCLUDE | grep -v "^[ ]*$")
        
        #        echo "bin  DEPS: $DEPS"
        local loop_cnt=0
        if [ "$DEPS" = "" ]
        then
            echo "]"
#            echo "#DEPS: \"$DEPS\""
        else
#            echo "#DEPS: \"$DEPS\""
            echo
            for dep in $DEPS
            do
                #            echo "dep: $dep [[$loop_cnt]]"
                if [ "$dep" != "" ]
                then
                    if [ $loop_cnt -ne 0 ]
                    then
                        echo -n ","
                    fi
                    loop_cnt=$(( $loop_cnt + 1 ))
                    #           echo "dep: $dep"
                    #          echo "------------------------"
                    #         echo find_lib $dep; find_lib $dep
                    #        echo "------------------------"
                    LIB=$(find_lib "$dep")
                    #      echo "------------------------"
#                    echo "\"$dep\" ===> \"$LIB\""
                    if [ "$LIB" = "" ]
                    then
                        err "Can't find lib path for $dep"
                        exit 2
                    fi
                    #      echo "------------------------"
                    print_artefact "$PKG" "$DIR" "$LIB" "$INDENT    "
                fi
            done
            echo "   ]"
        fi
        echo -n "$INDENT }"
    else
        echo "unknown file type for $PKG $DIR $ART"
        exit 2
    fi           
}

print_component()
{
    local PKG="$1"
    local DIR="$2"
#    print_package_sub_dir "$PKG"  "$DIR" 
    local ARTEFACTS=$(print_package_sub_dir "$PKG" "$DIR")
    if [ "$ARTEFACTS" != "" ]
    then
#        echo "$DIR"
        for art in $ARTEFACTS
        do
            echo "{ "
            echo "  \"component\": {"
            echo "     \"name\": \"$(basename $art)\","
            echo "     \"license\": \"unknown\","
            echo "     \"dependencies\": ["
            print_artefact "$PKG" "$DIR" "$art" "  "
            echo "       ]"
            echo "  }"
            echo "}"
            echo
        done
    else
        :
        #debug "ignoring $(basename $DIR)"
    fi
}

PKG_DIR=$(find_package_dir "$PKG")
#debug "PKG_DIR: $PKG_DIR"

PKG_DIRS=$(find_package_dirs "$PKG" "$PKG_DIR")
#debug "PKG_DIRS: $PKG_DIRS"

for pkg_dir in $PKG_DIRS
do
    #    debug " pkg_dir: $pkg_dir"
    JSON_FILE=${PKG}__$(basename ${pkg_dir}).json
    debugn "Calculating dependencies for: ${PKG} / $(basename ${pkg_dir}): "
    print_component $PKG $pkg_dir > $JSON_FILE
    if [ ! -s $JSON_FILE ]
    then
        debug " - nothing to report"
        rm $JSON_FILE
    else
        debug " - created $JSON_FILE"
    fi
done


