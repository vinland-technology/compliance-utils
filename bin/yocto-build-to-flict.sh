#!/bin/bash

# default
OUT_DIR=~/.vinland/compliance-utils/artefacts
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

# TODO: document
DIST_DIR=core2-64-poky-linux
# TODO: document
MACHINE=qemux86-64
# TODO: document
IMAGE=core-image-minimal-${MACHINE}
# TODO: document
DATE=20201024110850

TMP_WORK=tmp/work
if [ -z ${BUILD_DIR} ]
then
    BUILD_DIR=./tmp/work/$DIST_DIR
fi
if [ -z ${LICENSE_MANIFEST} ]
then
    LICENSE_MANIFEST=tmp/deploy/licenses/${IMAGE}-${DATE}/license.manifest
fi


declare -A LIB_DEPENDENCIES
export LIB_DEPENDENCIES

declare -A LIB_ARTEFACTS
export LIB_ARTEFACTS

declare -A LIB_PATHS
export LIB_PATHS

declare -A LIB_SHORT_NAME
export LIB_SHORT_NAME

declare -A LIB_LICENSE
export LIB_LICENSE


# TODO: configurable
READELF=readelf
# TODO: replace with list as reported by glibc

LIBC_EXCLUDE="" 
NONSENSE_EXCLUDE=" -e _z_z_z_z_z_z_z_z_z"


LIBC=true

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
        printf "\r                                                                      \r"
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

setup_glibc_excludes()
{
    local LIBS=$(find ${TMP_WORK}/$DIST_DIR/glibc/*/sysroot-destdir/ -name "lib*.so*" )
    for i in $LIBS
    do
        echo -n " -e $(basename $i) ";
    done
}

while [ "$1" != "" ]
do
    case "$1" in
        "--build-dir" | "-td")
            BUILD_DIR="$2"
            shift
            ;;
        "--image" | "-i")
            IMAGE="$2"
            shift
            ;;
        "--dist-dir" | "-dd")
            DIST_DIR="$2"
            shift
            ;;
        "--machine" | "-m")
            MACHINE="$2"
            shift
            ;;
        "--date" | "-d")
            DATE="$2"
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
        "--manage-artefacts" | "-ma")
            MANAGE_ARTEFACTS=true
            shift
            ;;
        "--help" | "-h")
            echo no not now
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

    #    err "find $BUILD_DIR/*/*/packages-split/*/usr/lib/ -name \"${LIB}*\" "
    LIB_PATH=$(find $BUILD_DIR/*/*/packages-split/*/usr/lib/ \
                    -name "${LIB}*" -type f| \
                   grep -v $EXCLUDES)
    if [ "$LIB_PATH" != "" ]
    then
        echo $LIB_PATH
        return
    fi
    LIB_PATH=$(find $BUILD_DIR/*/*/packages-split/*/usr/lib/ \
                    -name "${LIB}*" -type l| \
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
    LIB_PATH=$(find $BUILD_DIR/*/*/packages-split/*/lib/ \
                    -name "${LIB}*" -type l | \
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
    BB=$(find ../meta* -name "${PKG}*.bb" | grep -e "${PKG}/" -e  "/${PKG}" )
#    err "recipe for \"$PKG\": $BB"

    if [ "$BB" != "" ]
    then
        export LICENSE_COUNT=$(grep "LICENSE_\${PN}${ART_NAME_EXPR}" $BB | cut -d = -f 2 | sed 's,",,g' | wc -l)
#        err "count for \"$PKG\": $LICENSE_COUNT"
        # only one artefact? That's the case if LICENSE_COUNT==0
        if [ $LICENSE_COUNT -eq 0 ]
        then
            export LICENSE=$(grep "LICENSE" $BB | cut -d = -f 2 | sed 's,",,g')
        else
            export LICENSE=$(grep "LICENSE_\${PN}${ART_NAME_EXPR}" $BB | cut -d = -f 2 | sed 's,",,g')
        fi
    else
        err "Can't find recipe for \"$PKG\""
        export LICENSE=""
        export LICENSE_COUNT=0
        # TODO: exit or handle
        exit 100
    fi
#    err "LICENSE for $PKG: $LICENSE"
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

    # if cache, use it
    if [[ -v LIB_LICENSE[$ART_NAME] ]]
    then
        debug "cached license $ART_NAME = ${LIB_LICENSE[$ART_NAME]}"
        export LICENSE=${LIB_LICENSE[$ART_NAME]}
    fi

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
    LIB_LICENSE[$ART_NAME]="$LICENSE"
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
    
#    err "check type of \"$ART\""
    TYPE=$(file -b $ART)

    if [[ "${TYPE}" =~ "directory" ]]
    then
        err "$ART is a directory"
        exit 123
    elif [[ "${TYPE}" =~ "POSIX shell script" ]]
    then
        DISCARDED_ARTEFACTS="$DISCARDED_ARTEFACTS $ART"
        return
    elif [[ "${TYPE}" =~ "Python script" ]]
    then
        DISCARDED_ARTEFACTS="$DISCARDED_ARTEFACTS $ART"
        return
    elif [[ "${TYPE}" =~ "ASCII text" ]]
    then
        DISCARDED_ARTEFACTS="$DISCARDED_ARTEFACTS $ART"
        return
    elif [[ "${TYPE}" =~ "ASCII text executable" ]]
    then
        DISCARDED_ARTEFACTS="$DISCARDED_ARTEFACTS $ART"
        return
    elif [[ "${TYPE}" =~ "Unicode text" ]]
    then
        DISCARDED_ARTEFACTS="$DISCARDED_ARTEFACTS $ART"
        return
    elif [[ "${TYPE}" =~ "G-IR" ]]
    then
        DISCARDED_ARTEFACTS="$DISCARDED_ARTEFACTS $ART"
        return
    fi


    find_artefact_license $PKG $DIR $ART
    
    if [[ "${TYPE}" =~ "LSB shared object" ]]
    then
        if [ -z "$LICENSE" ]
        then
            DISCARDED_ARTEFACTS="$DISCARDED_ARTEFACTS $ART"
            LICENSE="unknown"
        fi
        echo "$INDENT {"
        echo "$INDENT   \"name\": \"$(basename $ART)\","
        echo "$INDENT   \"license\": \"$LICENSE\","
        echo -n "$INDENT   \"dependencies\": ["


        # if no cache, build it
        if [[ ! -v LIB_DEPENDENCIES[$ART] ]]
        then
            local DEPS=$($READELF -d $ART | grep NEEDED | cut -d ":" -f 2 | \
                   sed -e 's,^[ ]*\[,,g' -e 's,\]$,,g' | \
                   grep -v $LIBC_EXCLUDE | grep -v "^[ ]*$")
#            debug "caching: $ART  ($DEPS)"
            
            LIB_DEPENDENCIES[$ART]=$DEPS
            
 #           debug "## ${#LIB_DEPENDENCIES[@]} ## $ART ===> ${LIB_DEPENDENCIES[$ART]} "
#            for i in "${!LIB_DEPENDENCIES[@]}"
 #           do
  #              debug "     ## $i"
   #             debug "     ## value: ${LIB_DEPENDENCIES[$i]}"
    #        done
        else
            debug "using cache of: $ART"
        fi
        # use cached
        DEPS="${LIB_DEPENDENCIES[$ART]}"
        
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
                    if [[ ! -v LIB_PATHS[$dep] ]]
                    then
                        LIB_PATHS[$dep]=$(find_lib "$dep")
                    fi
                    LIB=${LIB_PATHS[$dep]}
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

    # If not in cache, add it
    if [[ ! -v LIB_SHORT_NAME[$DIR] ]]
    then
        LIB_SHORT_NAME[$DIR]=$(basename ${DIR})
    else
        debug "using cache of: $DIR"
    fi
    # use cached 
    PKG_DIR_SHORT="${LIB_SHORT_NAME[$DIR]}"
    
    #    print_package_sub_dir "$PKG"  "$DIR"

    debug "  - looking for artefacts in: $PKG ($DIR)"

    if [[ ! -v LIB_ARTEFACTS[$DIR] ]]
    then
        LIB_ARTEFACTS[$DIR]=$(print_package_split_dir "$PKG" "$DIR")
    else
        echo "using cache of: $DIR"
    fi
    local ARTEFACTS="${LIB_ARTEFACTS[$DIR]}"
    debug "  - artefacts: $ARTEFACTS"

    if [ "$ARTEFACTS" != "" ]
    then
        for art in $ARTEFACTS
        do
            ART_SHORT=$(basename $art)
            JSON_FILE=${OUT_DIR}/${PKG}__${PKG_DIR_SHORT}__${ART_SHORT}.json
            debug "    - print artefact: $art"
            debug "      - to json: $JSON_FILE"
#echo            print_artefact $PKG $DIR $art 

            print_artefact $PKG $DIR $art > $JSON_FILE
            if [ $(grep -c name $JSON_FILE) -eq 0 ]
            then
                rm $JSON_FILE
            fi
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
    verbose ""
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
  #  echo debug "SPLIT_PKGS_DIRS: ---->$SPLIT_PKGS_DIRS<---"
       
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
#echo            "split_pkg: $split_pkg" #  <---- $SPLIT_PKGS_DIRS"
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
    IMG_MF=tmp/deploy/images/${MACHINE}/${IMAGE}.manifest

    ARTEFACT_EXCLUDE_LIST="-e base-files -e hicolor-icon-theme -e iso-codes -e update-rc.d -e epiphany -e gcr -e busy -e desktop -e elfutils -e aspell -e dbus -e enchant -e passwd -e eudev -e fontconfig -e dazzle -e config -e asm1 -e atk -e arspi -e attr -e cairo -e cap2 -e crypt  -e glib -e gstreamer -e kernel -e atsp -e blkid -e elf -e mesa -e fonts -e ff -e freetype -e gbm -e gcc -e pixbuf -e glapi -e glib -e gnutls -e gpg -e stalloc -e gstdaudio -e tfft -e gstgl "
    ARTEFACTS=$(grep -v "\-lic " $IMG_MF | awk '{ print $1 }' | grep -v $ARTEFACT_EXCLUDE_LIST | sort -u)

    
    for art in $ARTEFACTS
    do
        SPLIT_PKG_NAME=$(find_artefact_split_package_name $art)
        debug "SPLIT_PKG_NAME: $SPLIT_PKG_NAME"

        if [ "$SPLIT_PKG_NAME" = "" ]
        then
            err "$art: no package found"
            UN_MANAGED_ARTEFACTS="$UN_MANAGED_ARTEFACTS $art"
        else
#            echo  "time: "
 #           time find_split_package_name_path $SPLIT_PKG_NAME
                        
            SPLIT_PKG=$(find_split_package_name_path $SPLIT_PKG_NAME)
            debug "SPLIT_PKG:      $SPLIT_PKG"
            
            PKG=$(find_split_package_package_name $SPLIT_PKG_NAME)
            debug "PKG:            $PKG"

            if [ "${MANAGE_ARTEFACTS}" = "true" ]
            then
                echo -n "$art: "
                print_split_package $PKG $SPLIT_PKG
                echo "OK"
            else
                echo "$art: "
                echo " - package     $PKG"
                echo " - split name  $SPLIT_PKG_NAME"
                echo " - split path  $SPLIT_PKG"
            fi
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
    LIB_EXCLUDE=$NONSENSE_EXCLUDE    
else
    setup_glibc_excludes
    LIB_EXCLUDE=$(setup_glibc_excludes)
fi
EXCLUDES="-e \.debug -e pkgconfig "
LIBC_EXCLUDE="$LIB_EXCLUDE"

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
elif [ "${LIST_ARTEFACTS}" = "true" ] ||  [ "${MANAGE_ARTEFACTS}" = "true" ]
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
    echo "Created: "
    for file in $JSON_FILES
    do
        echo " $file"
    done
fi
if [ "$DISCARDED_ARTEFACTS" != "" ]
then
    echo "Discard files:"
    echo $DISCARDED_ARTEFACTS | tr ' ' '\n' | sort -u | while read file
    do
        echo " $file"
    done
#    echo $DISCARDED_ARTEFACTS 
fi



