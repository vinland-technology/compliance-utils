#!/bin/bash

###################################################################
#
# FOSS Compliance Utils / spdx-license.sh
#
# SPDX-FileCopyrightText: 2020 Henrik Sandklef
#
# SPDX-License-Identifier: GPL-3.0-or-later
#
###################################################################

#
# Given license identifiers spdx-license creates
# a template JSON file with the licenses that lack
# SPDX identifier
#
# The resulting file can be used in with spdx-translations.py
# to translate license expressions such as "BSD 2 clause" to "BSD-2-Clause"

SPDX_LICENSES_URL="https://raw.githubusercontent.com/spdx/license-list-data/master/json/licenses.json"
SPDX_LICENSES_FILE_NAME="licenses.json"
VINLAND_BASE_DIR=~/.vinland

declare -A LICENSE_IDS
declare -A NEW_LICENSE_IDS

SPDX_LICENSES_FILE=${VINLAND_BASE_DIR}/${SPDX_LICENSES_FILE_NAME}

PROGRAM=$(basename $0)

if [ ! -d ${VINLAND_BASE_DIR} ]
then
    mkdir -p ${VINLAND_BASE_DIR}
fi

download_license_files()
{
    if [ ! -f ${SPDX_LICENSES_FILE} ] &&  [ ! -z ${SPDX_LICENSES_FILE} ]
    then
        curl -LJ -o ${SPDX_LICENSES_FILE} ${SPDX_LICENSES_URL} 
    fi
}

read_license_file()
{
    for id in $(jq ".licenses[].licenseId" ${SPDX_LICENSES_FILE} | sed 's,\",,g')
    do
        LICENSE_IDS[$id]="exists"
    done
}

print_keys()
{
    for KEY in "${!LICENSE_IDS[@]}"; do
        echo "\"$KEY\""
    done
}

parse()
{
    while [ "$1" != "" ]
    do
        case "$1" in
            "-")
                STDIN=true
                ;;
            "-h"|"--help")
                usage
                ;;
            *)
                ARG="$ARG $1"
                #echo "using $1"
                ;;
        esac
        shift
    done
}

collect_licenses_to_check()
{
    if [ "$ARG" = "" ] ||  [ "$STDIN" = "true" ]
    then
        TO_CHECK_LICENSES=$(cat)
    else
        TO_CHECK_LICENSES=""
        if [ -f $ARG ]
        then
            TO_CHECK_LICENSES=$(cat $ARG | tr '\n' ' ')
        else
            TO_CHECK_LICENSES="$ARG"
        fi
        
    fi
}    

assemble_new_licenses()
{
    for lic in $TO_CHECK_LICENSES
    do
        if [[ "${LICENSE_IDS[$lic]}" = "" ]]
        then
            NEW_LICENSE_IDS[$lic]="exists"
        else
            #echo no $lic
            :
        fi
    done
}

new_license()
{
    local license="$1"
    echo "      {"
    echo "        \"value\": \"$license\","
    echo "        \"spdx\": \"\","
    echo "        \"group\": \"\","
    echo "        \"comment\": \"\""
    echo -n "      }"
}

create_json()
{
    echo "{"
    echo "    \"spdx-translations\": ["
    FIRST=true
    for lic in "${!NEW_LICENSE_IDS[@]}"
    do
        if [ "$FIRST" = "true" ]
        then
            FIRST=false
        else
            echo ","
        fi
        new_license "$lic"
    done
    echo
    echo "    ]"
    echo "}"
}

usage()
{
    echo "NAME"
    echo "    $PROGRAM"
    echo
    echo "SYNOPSIS"
    echo "    $PROGRAM [OPTIONS] [ARGUMENT]"
    echo
    echo "DESCRIPTION"
    echo "    Checks a list of license identifiers if they are"
    echo "    SPDX identifiers. The non SPDX licenses are printed"
    echo "    in JSON format, as templates, for use with spdx-translations.py"
    echo
    echo "OPTIONS"
    echo "    -"
    echo "      read from stdin"
    echo 
    echo "    -h, --help"
    echo "      prints hits help text"
    echo
    echo "ARGUMENT"
    echo "    If argument is a file, that files is read (aassuming"
    echo "    the file contains one license per line)."
    echo "    If the argument is not a file the arguments is assumed"
    echo "    to be a license identifier"
    echo "    If no arguments, licenses are read from stdin (just as with -)"
    echo
    exit
}

parse $*

download_license_files

read_license_file

collect_licenses_to_check

assemble_new_licenses

create_json
