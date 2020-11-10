#!/bin/bash

###################################################################
#
# FOSS Compliance Utils / yocto-build-to-flict.sh
#
# SPDX-FileCopyrightText: 2020 Henrik Sandklef
#
# SPDX-License-Identifier: GPL-3.0-or-later
#
###################################################################

# default
OUT_DIR=~/.vinland/compliance-utils/artefacts
LIBC=false
DEBUG=false
PKG=""
SPLIT_PKG=""

DATE_FMT="%Y-%m-%d %H:%M:%S  %Z" 
CURRENT_DATE=$(date +"$DATE_FMT")

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
IMAGE=core-image-minimal-qemux86-64
# TODO: document
DATE=20201024110850

META_TOP_DIR=../


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
    local LIBS=$(find ${TMP_WORK}/$DIST_DIR/glibc/*/image/lib -name "*.so*")
    for i in $LIBS
    do
        echo -n " -e $(basename $i) ";
    done
}


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
#        echo "echo $ART_LINK | xargs readlink | xargs basename" >> /tmp/check.txt
        LINK=$(echo $ART_LINK | xargs readlink)
        if [ "${LINK}" = "" ]
        then
            echo ""
        fi
        basename "${LINK}"
    fi
}

usage()
{
    echo "NAME"
    echo "   $(basename $0)"
    echo
    
    echo "SYNOPSIS"
    echo "   $(basename $0) [OPTION] package"
    echo
    
    echo "DESCRIPTION"
    echo "   List information about packages from a Yocto build. The output"
    echo "   is designed to be used by flict (link below)"
    echo
    
    echo "OPTIONS"
    echo "   -bd, --build-dir <DIR>"
    echo "      Sets the build dir to DIR "
    echo
    echo "   -i, --image <IMAGE>"
    echo "      Sets the image dir to IMAGE "
    echo
    echo "   -mtd, --meta-top-dir <DIR>"
    echo "      Sets the top level directory for meta files (e.g. bitbake recipes)"
    echo
    echo "   -dd, --dist-dir <DIR>"
    echo "      Sets the distribution directory to DIR"
    echo
    echo "   -m, --machine <MACHINE>"
    echo "      Sets the machine to MACHINE"
    echo "      "
    echo
    echo "   -d, --date <DATE>"
    echo "      Set the date to DATE. This is needed to find license manifest"
    echo
    echo "   -od, --out-dir <DIR>"
    echo "      Set the output directory to DIR. Default is $OUT_DIR"
    echo
    echo "   -nl, --no-libc"
    echo "      Exclude all libc related dependencies"
    echo
    echo "   -v, --verbose"
    echo "      Enable verbose output"
    echo
    echo "   -sp, --split-package <SPLIT PACKAGE>"
    echo "      List only split package (sub package) for the package. Do not list all split packages."
    echo
    echo "   -a, --artefect <ARTEFECT>"
    echo "      Print information about ARTEFACT "
    echo
    echo "   -la, --list-artefacts"
    echo "     List all artefacts or if package is set (before -la) list all artefacts for that package"
    echo
    echo "   -ma, --manage-artefacts"
    echo "     Print information about all artefacts. Warning, there be dragons here"
    echo "     TOTALLY UNSUPPORTED!!"
    echo
    echo "    --help, h"
    echo "      Prints this help text."
    echo
    
    echo "ENVIRONMENT VARIABLES"
    echo "   The following environment variables can be used to tweak $PROG"
    echo 
    echo "   DIST_DIR (see -dd). Default is \"core2-64-poky-linux\""
    echo
    echo "   MACHINE (see -m).  Default is \"qemux86-64\""
    echo
    echo "   IMAGE (see -i). Default is \"core-image-minimal-qemux86-64\""
    echo 
    echo "   DATE (see -d). Default is \"20201024110850\""
    echo
    echo "   META_TOP_DIR (see -mtd).Default is \"../\""
    echo "   "
    
    echo "EXAMPLES"
    echo "   The examples below assume you have set the environment as desribed above"
    echo
    echo "   $ yocto-build-to-flict.sh -a bsdtar"
    echo "      Prints information about the split package bsdtar (from the package libarchive)"
    echo
    echo "   $ yocto-build-to-flict.sh libarchive"
    echo "      Prints information about the package libarchive"
    echo
    echo "   $ yocto-build-to-flict.sh libarchive -sp bsdtar"
    echo "      Prints information about the split package bsdtar from the package libarchive"
    echo
    echo "   $ yocto-build-to-flict.sh libarchive -la"
    echo "      List all artefacts"
    echo
    echo "   $ yocto-build-to-flict.sh libarchive -la"
    echo "      List all artefacts for libarchive"
    echo
    echo "      Prints information about the package libarchive"
    echo
    echo "AUTHOR"
    echo "    Written by Henrik Sandklef."
    echo ""
    echo "REPORTING BUGS"
    echo "    File an issue over at: https://github.com/vinland-technology/compliance-utils"
    echo ""
    echo "COPYRIGHT"
    echo "    Copyright © 2020 Henrik Sandklef"
    echo "    License GPLv3+: GNU GPL  version  3  or  later"
    echo "    <https://gnu.org/licenses/gpl.html>."
    echo "    This  is  free  software: you are free to change and redistribute it.  There is NO WARRANTY,"
    echo "    to the extent permitted by law."
    echo 
    echo "SEE ALSO"
    echo "    flict: https://github.com/vinland-technology/flict"
    echo
}

#
# For a given package split package name ($1) find the package
#
find_split_package_package_name()
{
    local SPLIT_PKG="$1"

    find $BUILD_DIR/*/*/packages-split/ -name "${SPLIT_PKG}" -type d | grep "packages-split/${SPLIT_PKG}[ ]*$" | grep -v "/src/" | sed 's,packages-split,\n,g' | head -1 | sed 's,/[-0-9a-zA-Z\.+_]*/$,,g' | xargs basename 2>/dev/null
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
    BB=$(find $META_TOP_DIR/meta* -name "${PKG}*.bb" | grep -e "${PKG}/" -e  "/${PKG}" )
#    err "recipe for \"$PKG\": $BB"

    if [ "$BB" != "" ]
    then
        export LICENSE_COUNT=$(grep "LICENSE_\${PN}${ART_NAME_EXPR}" $BB | cut -d = -f 2 | sed 's,",,g' | wc -l)
#        err "count for \"$PKG\": $LICENSE_COUNT"
        # only one artefact? That's the case if LICENSE_COUNT==0
        if [ $LICENSE_COUNT -eq 0 ]
        then
            export LICENSE=$(grep "LICENSE" $BB | cut -d = -f 2 | sed 's,",,g')
            export LICENSE_COUNT=$(grep "LICENSE" $BB | cut -d = -f 2 | sed 's,",,g' | wc -l)
        else
            export LICENSE=$(grep "LICENSE_\${PN}${ART_NAME_EXPR}" $BB | cut -d = -f 2 | sed 's,",,g')
        fi
    else
        err "Can't find recipe for \"$PKG\", using META_TOP_DIR=$META_TOP_DIR"
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

updatelib_deps()
{
 #   err "update "
  #  err "update \"$1\""
  #  err "update ==============================================================================================0"
  #  err "update --> \"$1\": ${LIB_DEPENDENCIES[${1}]}"
  #  err "     ---> update keys"
    for i in "${!LIB_DEPENDENCIES[@]}"
    do
   #     err "update key  : $i ( ${#LIB_DEPENDENCIES[$i]})"
        #            err "value: ${LIB_DEPENDENCIES[$i]}"
        :
    done
    if [ "$2" = "" ]
    then
        LIB_DEPENDENCIES["${1}"]="dummy"
    else
        LIB_DEPENDENCIES["${1}"]="$2"
    fi
#    err "     <--- update keys"
    for i in "${!LIB_DEPENDENCIES[@]}"
    do
#        err "update key  : $i ( ${#LIB_DEPENDENCIES[$i]})"
        #            err "value: ${LIB_DEPENDENCIES[$i]}"
        :
    done
    
}
    
print_artefact_deps()
{
    local PKG="$1"
    local DIR="$2"
    local ART="$3"
    local INDENT="$4"

    verbose_spin

#    debug "   $INDENT- print: $ART"
    
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
    local TYPE=$(file -b $ART)

    if [[ "${TYPE}" =~ "directory" ]]
    then
        err "$ART is a directory"
        exit 123
    elif [[ "${TYPE}" =~ "POSIX shell script" ]]
    then
        DISCARDED_ARTEFACTS="$DISCARDED_ARTEFACTS $ART"
        return
    elif [[ "${TYPE}" =~ "current ar archive" ]]
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

        local DEPS
        # if no cache, build it
        if [[ "${LIB_DEPENDENCIES[$ART]}" = "" ]] && [[ "${LIB_DEPENDENCIES[$ART]}" != "*dummy" ]]
        then
#            err "read and cache 1: $ART since = \"${LIB_DEPENDENCIES[$ART]}\" (#: ${#LIB_DEPENDENCIES[@]})"

            DEPS="$($READELF -d $ART | grep NEEDED | cut -d ":" -f 2 | \
                   sed -e 's,^[ ]*\[,,g' -e 's,\]$,,g' | \
                   grep -v $LIBC_EXCLUDE | grep -v "^[ ]*$" | tr '\n' ' ')"

 #           err "DEPS: \"$DEPS\""
  #          err "caching: $ART 1 (DEPS:\"$DEPS\")"

   #         err ""

            updatelib_deps "$ART" "$DEPS"

#            err "read and cache 2: $ART since = \"${LIB_DEPENDENCIES[$ART]}\" (#: ${#LIB_DEPENDENCIES[@]})"
 #           err "caching: $ART 2  (DEPS:\"${LIB_DEPENDENCIES[${ART}]}\")"
#            err "caching: $(basename $ART)  => $(echo ${DEPS}                   | tr '\n' ' ')"
 #           debug "## ${#LIB_DEPENDENCIES[@]} ## $ART ===> ${LIB_DEPENDENCIES[$ART]} "
#            for i in "${!LIB_DEPENDENCIES[@]}"
 #           do
  #              debug "     ## $i"
   #             debug "     ## value: ${LIB_DEPENDENCIES[$i]}"
            #        done
        else
            #            err "using cache for $ART"
            :
        fi
        # use cached
        DEPS="${LIB_DEPENDENCIES[$ART]}"
#        echo "hesa  DEPS: $DEPS " # (using $LIBC_EXCLUDE)

        local loop_cnt=0
        if [ "$DEPS" = "" ] || [ "$DEPS" = "dummy" ] 
        then
            echo "]"
#            echo "#DEPS: \"$DEPS\""
        else
#            echo "#DEPS: \"$DEPS\""
            for dep in $DEPS
            do
                #            echo "dep: $dep [[$loop_cnt]]"
                if [ "$dep" != "" ]
                then
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
                    print_artefact_deps "$PKG" "$DIR" "$LIB" "$INDENT    " 
                    if [ $loop_cnt -ne 0 ]
                    then
                        debug "loop_cnt: $loop_cnt, adding ,"
                        echo -n ","
                        
                    else
                        debug "loop_cnt: $loop_cnt, ignore ,"
                    fi
                    echo -n "$RES"
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
            # ugly fix
            sed -i 's/}[ \n]*{/},{/g'  $JSON_FILE
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



#
# handle_artefact
#
# description: given the artefact ($1) this function:
#  finds the split package name as well as the package name
#  and then prints the artefact 
# 
# 
handle_artefact()
{
    debug "handle_artefact $1"

    SPLIT_PKG_NAME=$(find_artefact_split_package_name $1)
    debug "SPLIT_PKG_NAME: $SPLIT_PKG_NAME"
    if [ "$SPLIT_PKG_NAME" = "" ]
    then
        err "Can't find split package name for artefact: $1"
        err "Perhaps your DIST_DIR ($DIST_DIR) is incorrect."
        err "If so, try -dd <DIR>"
        err "...."
        # TODO: exit code
        exit 213
    fi
        

    SPLIT_PKG=$(find_split_package_name_path $SPLIT_PKG_NAME)
    debug "SPLIT_PKG:      $SPLIT_PKG"

    PKG=$(find_split_package_package_name $SPLIT_PKG_NAME)
    debug "PKG:            $PKG"

    print_split_package $PKG $SPLIT_PKG
}

ARTEFACTS_JSON=artefacts.json
artefact_json()
{
    echo "$*" | tee -a ${ARTEFACTS_JSON}
}

list_artefacts()
{
    IMG_MF=tmp/deploy/images/${MACHINE}/${IMAGE}.manifest
    debug "list_artefacts from $IMG_MF"
    err- "list_artefacts from $IMG_MF"

    if [ ! -f $IMG_MF ]
    then
        err "Can't find manifest file"
        err " MACHINE:  $MACHINE"
        err " IMAGE:    $IMAGE"
        err " MANIFEST: $IMG_MF"
        exit 103
    fi
    
    ARTEFACTS=$(grep -v "\-lic " $IMG_MF | awk '{ print $1 }' | sort -u)

    rm -f ${ARTEFACTS_JSON}

    artefact_json "{"
    artefact_json "  \"meta\": {"
    artefact_json "    \"date\": \"${CURRENT_DATE}\","
    artefact_json "    \"host\": \"$(uname -a)\","
    artefact_json "    \"user\": \"$(whoami)\""
    artefact_json "  },"
    artefact_json "  \"build-information\": {"
    artefact_json "    \"image\": \"${IMAGE}\","
    artefact_json "    \"machine\": \"${MACHINE}\","
    artefact_json "    \"manifest\": \"${IMG_MF}\""
    artefact_json "  },"
    artefact_json "  \"artefacts\": ["

    FAILED_ARTEFACTS=""
    FIRST_ARTEFACT=true
    for art in $ARTEFACTS
    do
        SPLIT_PKG_NAME=$(find_artefact_split_package_name $art)
        debug "SPLIT_PKG_NAME: $SPLIT_PKG_NAME"

        if [ "$SPLIT_PKG_NAME" = "" ]
        then
            err "Can't find split package name for artefact: $art"
            FAILED_ARTEFACTS="$FAILED_ARTEFACTS $art" 
            continue
        fi
        
        SPLIT_PKG=$(find_split_package_name_path $SPLIT_PKG_NAME)
        debug "SPLIT_PKG:      $SPLIT_PKG"
        
        PKG=$(find_split_package_package_name $SPLIT_PKG_NAME)
        debug "PKG:            $PKG"
        
        if [ "$PKG" = "" ]
        then
            err "Can't find package name for artefact: $art"
            FAILED_ARTEFACTS="$FAILED_ARTEFACTS $art" 
            continue
        fi

        if [ "${MANAGE_ARTEFACTS}" = "true" ]
        then
            echo -n "$art: "
            print_split_package $PKG $SPLIT_PKG
            echo "OK"
        else
            if [ "$FIRST_ARTEFACT" = "true" ]
            then
                FIRST_ARTEFACT=false
            else
                artefact_json "   ,"
            fi
            artefact_json "   {"
            artefact_json "     \"name\": \"$art\","
            artefact_json "     \"package\": \"$PKG\","
            artefact_json "     \"split-package-name\": \"$SPLIT_PKG_NAME\","
            artefact_json "     \"split-package\": \"$SPLIT_PKG\""
            artefact_json "   }"
        fi
        #   fi
    done
    artefact_json "  ]"

#    if [ "$UN_MANAGED_ARTEFACTS" != "" ]
 #   then
  #      artefact_json ","
   #     artefact_json "  \"unmanaged_artefacts\": \"$UN_MANAGED_ARTEFACTS\""
    #fi
    artefact_json ","
    artefact_json "  \"failed_artefacts\": \"$FAILED_ARTEFACTS $ARTEFACT\"" 
    artefact_json "}"
}


#
# parse
#

while [ "$1" != "" ]
do
    case "$1" in
        "--build-dir" | "-bd")
            BUILD_DIR="$2"
            shift
            ;;
        "--image" | "-i")
            IMAGE="$2"
            shift
            ;;
        "--meta-top-dir" | "-mtd")
            META_TOP_DIR="$2"
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
        "--out-dir" | "-od")
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
            usage
            exit 0
            ;;
        *)
            # assume package
            PKG="$1"
    esac
    shift
done

guess_settings()
{
    MACHINE=$(grep MACHINE conf/local.conf | grep -v "^#" | cut -d "=" -f 2 | sed -e 's,[ "]*,,g')
    
}
#
# prepare
#

TMP_WORK=tmp/work
if [ -z ${BUILD_DIR} ]
then
    BUILD_DIR=./tmp/work/$DIST_DIR
fi
if [ -z ${LICENSE_MANIFEST} ]
then
    LICENSE_MANIFEST=tmp/deploy/licenses/${IMAGE}-${DATE}/license.manifest
fi
if [ ! -f $LICENSE_MANIFEST ]
then
    err "Can't find license manifest file"
    err " \"$LICENSE_MANIFEST\""
    err "If you set it yourself, make sure your path is correct"
    err "else, check your settings for:"
    err "  IMAGE: $IMAGE"
    err "  DATE:  $DATE"
    err " .... leaving"
    exit 104
fi


if [ "$BUILD_DIR" = "" ] 
then
    err "No build dir specified"
    exit 2
fi

if [ ! -d $BUILD_DIR ] 
then
    err "Build dir not found"
    err "  BUILD_DIR: $BUILD_DIR"
    err "... leaving"
    exit 2
fi


if [ "$LIBC" = "true" ]
then
    LIB_EXCLUDE=$NONSENSE_EXCLUDE    
else
#    setup_glibc_excludes
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
    usage
    exit 2
fi


#
# reporting
#
if [ "$JSON_FILES" != "" ]
then
    echo
    echo "Created: "
    for file in $JSON_FILES
    do
        echo " $file"
    done
fi
if [ "$DISCARDED_ARTEFACTS" != "" ]
then
    err "Discarded files:"
    err $DISCARDED_ARTEFACTS | tr ' ' '\n' | sort -u | while read file
    do
        err " $file"
    done
#    echo $DISCARDED_ARTEFACTS 
fi



