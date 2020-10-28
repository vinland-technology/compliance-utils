#!/bin/bash

# default
OUT_DIR=~/.vinland-compliance-utils/artefacts
LIBC=false
DEBUG=true
PKG=""
SPLIT_PKG=""

# Nomenclature
# --------------------
# package
# - as defined in yocto (e.g. cairo)
#
# split package
# - basically dirs corresponding to a package under the
#   "major" package (e.g cairo-gobject). Name taken from the Yocto directory
#    packages-split where we can find these
# 
# artefact
# - something build within a sub package
#   e.g (libcairo-gobject.so.2.11600.0)
#   corresponds to flict's component
#
#
if [ -z ${BUILD_DIR} ]
then
    BUILD_DIR=./tmp/work/core2-64-poky-linux
fi

LIBC_EXCLUDE=" -e GLIBC -e libpthread -e librt -e libc.so -e libdl -e libc6 -e rtld -e \"/bin/sh\" -e libc\.so -e ld-linux -e libm\.so" 
NONSENSE_EXCLUDE=" -e _z_z_z_z_z_z_z_z_z"

LIBC=true
EXCLUDES="-e \.debug -e pkgconfig "

VERBOSE=false
VERBOSE_SPINNER=(\| / - \\ ); 
VERBOSE_SPINNER_SIZE=${#VERBOSE_SPINNER[@]};
VERBOSE_SPINNER_COUNT=0

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

verbose()
{
    if [ "$VERBOSE" = "true" ]
    then
        printf "$*" 1>&2
    fi
}

verbosen()
{
    if [ "$VERBOSE" = "true" ]
    then
        printf "$*" 1>&2
    fi
}

verbose_spin()
{
    if [ "$VERBOSE" = "true" ]
    then
        IDX=$(( $VERBOSE_SPINNER_COUNT % $VERBOSE_SPINNER_SIZE)) ;
        CHAR=${VERBOSE_SPINNER[$IDX]};
        printf "\b\b %s" "$CHAR"  1>&2
        VERBOSE_SPINNER_COUNT=$(( VERBOSE_SPINNER_COUNT + 1 ))
    fi
}

verbose_clean()
{
    if [ "$VERBOSE" = "true" ]
    then
        # Uh oh, dirty hack
        printf "\r                                                                             \r"
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
        "--OUT-dir" | "-td")
            OUT_DIR="$2"
            shift
            ;;
        "--no-libc" | "-nl")
            LIBC=false
            ;;
        "--verbose" | "-v")
            VERBOSE=true
            ;;
        "--split-package" | "-sp")
            SPLIT_PKG=$2
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



if [ "$PKG" = "" ]
then
    err "No package specified"
    exit 2
fi

if [ "$BUILD_DIR" = "" ]
then
    err "No build dir specified"
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

#
# For a given package ($1) finds that package's directory
#
find_package_dir()
{
    local PKG="$1"
    find $BUILD_DIR/$PKG/*/packages-split/ -type d -prune
}

#
# For a given package ($1) and package dir ($2) finds directories to the 
#
find_package_dirs()
{
    local PKG="$1"
    local DIR="$2"
    find $DIR/* -type d -prune | grep -v "${PKG}-lic$"
}

print_package_split_dir()
{
    local PKG="$1"
    local DIR="$2"
    local COMP=$(basename $DIR)

    find $DIR/*/lib $DIR/*/usr/lib $DIR/*/bin $DIR/*/usr/bin -type f  \
         2>/dev/null  | \
        grep -v $EXCLUDES
}

print_artefact_deps()
{
    local PKG="$1"
    local DIR="$2"
    local ART="$3"
    local INDENT="$4"

    verbose_spin

    debug "   $INDENT- print: $ART"
    
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
        DISCARDED_SCRIPTS="$DISCARDED_SCRIPTS $ART" 
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
                    print_artefact_deps "$PKG" "$DIR" "$LIB" "$INDENT    "
                fi
            done
            echo "   ]"
        fi
        echo -n "$INDENT }"
    else
        err "Unknown file type for:"
        err " * type:      $TYPE"
        err " * package:   $PKG"
        err " * directory: $DIR"
        err " * artefact:  $ART"
        exit 2
    fi           
}

print_artefact()
{
    local PKG="$1"
    local DIR="$2"
    local ART="$3"
    debug "   print artefact: $ART"
    echo "{ "
     echo "  \"component\": "
#    echo "  \"component\": {"
#    echo "     \"name\": \"$(basename $art)\","
#    echo "     \"license\": \"unknown\","
#    echo "     \"dependencies\": ["
     print_artefact_deps "$PKG" "$DIR" "$ART" "  "
#    echo "       ]"
#    echo "  }"
    echo "}" 
    echo
}

print_split_package_helper()
{
    local PKG="$1"
    local DIR="$2"

    PKG_DIR_SHORT=$(basename ${DIR})
    
    #    print_package_sub_dir "$PKG"  "$DIR"

    debug "  - looking for sub packages in: $PKG ($DIR)"
    
    local ARTEFACTS=$(print_package_split_dir "$PKG" "$DIR")
    debug "  - artefacts: $ARTEFACTS"
    if [ "$ARTEFACTS" != "" ]
    then
        for art in $ARTEFACTS
        do
            ART_SHORT=$(basename $art)
            JSON_FILE=${OUT_DIR}/${PKG}__${PKG_DIR_SHORT}__${ART_SHORT}.json
            debug "    - print artefact: $art"
            debug "      - to json: $JSON_FILE"
            print_artefact $PKG $DIR $art > $JSON_FILE
        done
        
        if [ ! -s $JSON_FILE ]
        then
            debug " - nothing to report"
        else
            debug " - created $JSON_FILE"
            JSON_FILES="$JSON_FILES $JSON_FILE"
        fi
        
    else
        :
        #debug "ignoring $(basename $DIR)"
    fi
}

print_split_package()
{
    local PKG="$1"
    local DIR="$2"

    err "  print_split_package($1,$2)"
    
    PKG_DIR_SHORT=$(basename ${DIR})
    debug "Calculating dependencies for: ${PKG} / ${PKG_DIR_SHORT}: "
    verbosen "Calculating dependencies for ${PKG} / ${PKG_DIR_SHORT}:  "
    
    print_split_package_helper $PKG $DIR 
    
    verbose_clean
}


handle_package()
{
    local PKG="$1"

    # package is specified - let's find artefacts
    local PKG_DIR=$(find_package_dir "$PKG")
    debug "PKG_DIR:         $PKG_DIR"
    
    local SPLIT_PKGS_DIRS=$(find_package_dirs "$PKG" "$PKG_DIR" | sort -r)
#    debug "SPLIT_PKGS_DIRS: $SPLIT_PKGS_DIRS"

    JSON_FILES=""
    if [ ! -z $SPLIT_PKG ]
    then
        debug "SPLIT_PKG set to $SPLIT_PKG"
        # PKG and artefact, keep only $SPLIT_PKG        
        SPLIT_PKGS_DIRS=$(find_package_dirs "$PKG" "$PKG_DIR" | egrep "/${SPLIT_PKG}$" | sort -r)
        debug "SPLIT_PKGS: $SPLIT_PKGS_DIRS"
    fi

#    echo debug "PKG:      $PKG"
 #   echo debug "PKG_DIR:  $PKG_DIR"
#    echo debug "SPLIT_PKG_DIRS: ---->$SPLIT_PKG_DIRS<---"

    debug "SPLIT_PKGS_DIRS: $SPLIT_PKGS_DIRS"

    if [ -z "${SPLIT_PKGS_DIRS}" ]
    then
        err "No artefacts macthing \"$SPLIT_PKG\" found in \"$PKG\"."
        exit 
    else
        # PKG but no artefact
        # - loop through all artefacts
        for split_pkg in $SPLIT_PKGS_DIRS
        do
            print_split_package $PKG $split_pkg
        done
    fi
}


if [ ! -d ${OUT_DIR} ]
then
    mkdir -p ${OUT_DIR}
fi

if [ ! -z ${PKG} ]
then
    handle_package "${PKG}"
else
    :
    echo "NOT IMPLEMENTED YET:....."
fi
echo "Created: $JSON_FILES"
echo "Discard scripts: $DISCARDED_SCRIPTS"



