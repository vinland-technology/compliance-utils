#!/bin/bash

# default
OUT_DIR=~/.vinland-compliance-utils/artefacts
LIBC=false
DEBUG=false
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
DEFAULT_DIR=core2-64-poky-linux
if [ -z ${BUILD_DIR} ]
then
    BUILD_DIR=./tmp/work/$DEFAULT_DIR
fi
if [ -z ${LICENSE_MANIFEST} ]
then
    LICENSE_MANIFEST=tmp/deploy/licenses/core-image-minimal-qemux86-64-20201024110850/license.manifest
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
        "--artefect" | "-a")
            ARTEFACT=$2
            shift
            ;;
        "--list-artefacts" | "-la")
            LIST_ARTEFACTS=true
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
# For a given artefact ($1) finds the coresponding package split name
#
find_artefact_split_package_name()
{
    local ART="$1"

    
    ART_LINK=$(find $BUILD_DIR/*/*/*/runtime-reverse -name "${ART}" -type l | grep runtime-reverse | head -1)

    if [ "$ART_LINK" = "" ]
    then
        echo ""
    else
        echo $ART_LINK | xargs readlink | xargs basename
    fi
}

#
# For a given package split package name ($1) find the package
#
find_split_package_package_name()
{
    local SPLIT_PKG="$1"

    find $BUILD_DIR/*/*/packages-split/ -name "${SPLIT_PKG}" -type d | grep "packages-split/${SPLIT_PKG}[ ]*$" | grep -v "/src/" | sed 's,packages-split,\n,g' | head -1 | sed 's,/[-0-9a-zA-Z\.+_]*/$,,g' | xargs basename
}

#
# For a given package split package name ($1) find the path
#
find_split_package_name_path()
{
    local SPLIT_PKG="$1"
    find $BUILD_DIR/*/*/packages-split/ -name "${SPLIT_PKG}" -type d | grep "packages-split/*${SPLIT_PKG}[ ]*$" | grep -v -e "/src/" | grep "${SPLIT_PKG}$"
}

#
# For a given package ($1) and package dir ($2) finds directories to the 
#
find_package_dirs()
{
    local PKG="$1"
    local DIR="$2"
    find ${DIR}* -type d -prune | grep -v "${PKG}-lic$" 
}

find_artefact_license_bb()
{
    # BLOG
    local PKG=$1
    local ART_NAME=$2
    local SPLIT_PKG_NAME=$2
    # TODO: fix this path

    export LOCAL_PKG=$PKG
    ART_NAME_EXPR=$(echo $ART_NAME | sed -e "s,$LOCAL_PKG,,g")
    BB=$(find ../meta* -name "${PKG}*.bb" | grep "${PKG}/")

    export LICENSE=$(grep "LICENSE_\${PN}${ART_NAME_EXPR}" $BB | cut -d = -f 2 | sed 's,",,g')
    export LICENSE_COUNT=$(grep "LICENSE_\${PN}${ART_NAME_EXPR}" $BB | cut -d = -f 2 | sed 's,",,g' | wc -l)
}
    

#
#
# 
find_artefact_license()
{
    local PKG="$1"
    local DIR="$2"
    local ART="$3"

    ART_NAME=$(echo $ART | sed 's,packages-split/,\n,g' | tail -1 | cut -d "/" -f 1)
    
#    SPLIT_PKG_NAME=$(basename $DIR)

#    debug "    find license for $BUILD_DIR"
#    debug "    PKG:   $PKG"
#    debug "    DIR:   $DIR"
 #   debug "    ART:   $ART"
#    debug "    SPLIT: $SPLIT_PKG_NAME"

    if [ -z "$ART_NAME" ]
    then
        err "Failed to find license for $ART"
        exit 100
    fi
    
#    LICENSE=$(grep -A 3 "PACKAGE NAME: $ART_NAME[ ]*$"  $LICENSE_MANIFEST | grep LICENSE | cut -d : -f 2)
    LICENSE=$(grep -A 3  "PACKAGE NAME: $ART_NAME[ ]*$"  $LICENSE_MANIFEST | grep LICENSE | cut -d : -f 2)
    LICENSE_COUNT=$(grep -A 3  "PACKAGE NAME: $ART_NAME[ ]*$"  $LICENSE_MANIFEST | grep LICENSE | cut -d : -f 2 | wc -l)

    
    if [ -z "$LICENSE" ] || [ $LICENSE_COUNT -ne 1 ]
    then
        find_artefact_license_bb $PKG $ART_NAME $SPLIT_PKG_NAME
        
        if [ -z "$LICENSE" ] || [ $LICENSE_COUNT -ne 1 ]
        then
            err "Failed to find one (found $LICENSE_COUNT) license expression for $ART ($LICENSE)"
            err " *      PKG:           $PKG"
            err " *      ART:           $ART"
            err " *      ART_NAME:      $ART_NAME"
            err " *      LICENSE_COUNT: $LICENSE_COUNT"
            err " *      LICENSE:       $LICENSE"
            err " *      MANIFEST:      $LICENSE_MANIFEST"
        fi
    fi
    
    export LICENSE
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

  #  debug "license:"
 #   debug " * $DIR"
    #    debug " * $ART"
    find_artefact_license $PKG $DIR $ART
    if [ -z "$LICENSE" ]
    then
        DISCARDED_ARTEFACTS="$DISCARDED_ARTEFACTS $ART"
        LICENSE="unknown"
    fi
    
 #   echo " - type $TYPE "
    if [[ "${TYPE}" =~ "POSIX shell script" ]]
    then
        DISCARDED_SCRIPTS="$DISCARDED_SCRIPTS $ART" 
    elif [[ "${TYPE}" =~ "LSB shared object" ]]
    then
        echo "$INDENT {"
        echo "$INDENT   \"name\": \"$(basename $ART)\","
        echo "$INDENT   \"license\": \"$LICENSE\","
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

    debug "  print_split_package($1,$2)"
    
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
    debug "SPLIT_PKGS_DIRS: $SPLIT_PKGS_DIRS"

    JSON_FILES=""
    if [ ! -z $SPLIT_PKG ]
    then
        debug "SPLIT_PKG set to $SPLIT_PKG"
        # PKG and artefact, keep only $SPLIT_PKG        
        SPLIT_PKGS_DIRS=$(find_package_dirs "$PKG" "$PKG_DIR" | egrep "/${SPLIT_PKG}$" | sort -r)
        debug "SPLIT_PKGS_DIR: $SPLIT_PKGS_DIRS"
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

handle_artefact()
{
    debug "handle_artefact $1"

    SPLIT_PKG_NAME=$(find_artefact_split_package_name $1)
    debug "SPLIT_PKG_NAME: $SPLIT_PKG_NAME"

    SPLIT_PKG=$(find_split_package_name_path $SPLIT_PKG_NAME)
    debug "SPLIT_PKG:      $SPLIT_PKG"

    PKG=$(find_split_package_package_name $SPLIT_PKG_NAME)
    debug "PKG:            $PKG"

    print_split_package $PKG $SPLIT_PKG
    

}

list_artefacts()
{
    debug "list_artefacts $1"

    #TODO: remove hard coded path
    IMG_MF=tmp/deploy/images/qemux86-64/core-image-minimal-qemux86-64.manifest

    ARTEFACT_EXCLUDE_LIST="-e base-files -e hicolor-icon-theme -e iso-codes -e update-rc.d "
    ARTEFACTS=$(grep -v "\-lic " $IMG_MF | awk '{ print $1 }' | grep -v $ARTEFACT_EXCLUDE_LIST | sort -u)

    
    for art in $ARTEFACTS
    do
        SPLIT_PKG_NAME=$(find_artefact_split_package_name $art)
        debug "SPLIT_PKG_NAME: $SPLIT_PKG_NAME"

        echo -n "$art: "
        if [ "$SPLIT_PKG_NAME" = "" ]
        then
            UN_MANAGED_ARTEFACTS="$UN_MANAGED_ARTEFACTS $art"
            echo " no package found"
        else
#            echo  "time: "
 #           time find_split_package_name_path $SPLIT_PKG_NAME
                        
            SPLIT_PKG=$(find_split_package_name_path $SPLIT_PKG_NAME)
            debug "SPLIT_PKG:      $SPLIT_PKG"
            
            PKG=$(find_split_package_package_name $SPLIT_PKG_NAME)
            debug "PKG:            $PKG"
            echo
            echo " - package     $PKG"
            echo " - split name  $SPLIT_PKG_NAME"
            echo " - split path  $SPLIT_PKG"
        fi
        
        
    done
    if [ "$UN_MANAGED_ARTEFACTS" != "" ]
    then
        echo "Unmanaged artefacts:"
        echo " - $UN_MANAGED_ARTEFACTS"
    fi
}


#
# prepare
#
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

if [ ! -d ${OUT_DIR} ]
then
    mkdir -p ${OUT_DIR}
fi

#
# main
#
if [ ! -z ${PKG} ]
then
    handle_package "${PKG}"
elif [ "${LIST_ARTEFACTS}" = "true" ]
then
    list_artefacts
elif [ ! -z ${ARTEFACT} ]
then
    handle_artefact $ARTEFACT
else
    echo "SYNTAX ERROR"
    exit 2
fi


#
# reporting
#
if [ "$JSON_FILES" != "" ]
then
    echo "Created: $JSON_FILES"
fi
if [ "$DISCARDED_SCRIPTS" != "" ]
then
    echo "Discard scripts: $DISCARDED_SCRIPTS"
fi



