#!/bin/sh

##############################################################################
#
# FOSS Compliance Utils / check-compat.sh
#
# SPDX-FileCopyrightText: 2020 Henrik Sandklef
#
# SPDX-License-Identifier: GPL-3.0-or-later
#
#
# Simple wrapper over "flict -cc LICENSES"
#
# With this tool you can check if a bunch of licenses, typically as
# gathered from a packages and its dependencies, are compatible and
# get the flict (link below) result filtered. Example:
#
#   $ check-compat.sh -nr MIT BSD BSD-2-Clause LGPL-2.1-only PSF
#   Checking compat between  MIT BSD BSD-2-Clause LGPL-2.1-only PSF
#   Non compatible:
#   LGPL-2.1-only –//– Python-2.0
#   Python-2.0 –//– LGPL-2.1-only
#
# From this you can draw the conclusion that the package you're
# checking can't be combined this way with regards to the licenses.
#
# Note: for now you can not use any boolean operators (such as
# 'or'). If you want to do so, read up on flict
#
# flict: https://github.com/vinland-technology/flict
#
##############################################################################

TMP_FILE=/tmp/check-compat-$USER-$$.flict
FLICT_URL=https://github.com/vinland-technology/flict

VERSION_FILE=$(dirname ${BASH_SOURCE[0]})/../VERSION
CU_VERSION=$(cat ${VERSION_FILE})
if [ -z ${CU_VERSION} ]
then
    echo "WARNING: Could not retrieve version from $VERSION_FILE" 1>&2
    CU_VERSION="unknown"
fi

#echo "TMP_FILE: $TMP_FILE"

SHOW_MUTUAL=false
SHOW_ONE_WAY=false
SHOW_NON_COMPAT=true

REGEXP=""
FLICT_ARGS=""

MYNAME=check-compat.sh

usage()
{
    echo "NAME"
    echo ""
    echo "    ${MYNAME} - checks compatibility between licenses"
    echo ""
    echo
    echo "SYNOPSIS"
    echo
    echo "    ${MYNAME} [OPTION] <LICENSES>"
    echo ""
    echo ""
    echo "DESCRIPTION"
    echo ""
    echo ""
    echo ""
    echo "OPTIONS"
    echo ""
    echo "    -nr, --no-relicense"
    echo "          do NOT use license relicensing (such as GPL-2.0-or-later"
    echo "          can relicensed to GPL-3.0-or-later)"
    echo
    echo "    -v, --verbose"
    echo "          enable verbose printout"
    echo
    echo "    --version"
    echo "          output version information"
    echo
    echo "EXAMPLES"
    echo ""
    echo "    $ check-compat.sh -nr MIT BSD BSD-2-Clause LGPL-2.1-only PSF"
    echo "    Checking compat between  MIT BSD BSD-2-Clause LGPL-2.1-only PSF"
    echo "    Non compatible:"
    echo "    LGPL-2.1-only –//– Python-2.0"
    echo "    Python-2.0 –//– LGPL-2.1-only"
    echo
    echo "AUTHOR"
    echo ""
    echo "    Written by Henrik Sandklef"
    echo
    echo
    echo "COPYRIGHT"
    echo ""
    echo "    Copyright (c) 2021 Henrik Sandklef"
    echo "    License GPLv3+: GNU GPL version 3 or later <https://gnu.org/licenses/gpl.html>."
    echo "    This  is  free  software: you are free to change and redistribute it.  "
    echo "    There is NO WARRANTY, to the extent permitted by law."
    echo
    echo
    echo "REPORTING BUGS"
    echo ""
    echo "    Create an issue at https://github.com/vinland-technology/compliance-utils"
    echo
    echo
    echo "SEEL ALSO"
    echo ""
    echo "    flict ($FLICT_URL)"
    echo
    echo
    
}

#
# parse command line arguments
#
while [ "$1" != "" ]
do
    case "$1" in
        "-nr"|"--no-relicense")
            FLICT_ARGS="$FLICT_ARGS -nr"
            ;;
        "-v"|"--verbose")
            FLICT_ARGS="$FLICT_ARGS -v"
            ;;
        "-h"|"--help")
            usage
            exit 0
            ;;
        "version"|"--version"|"-V")
            echo ${CU_VERSION}
            exit 0
            ;;
        *)
            #echo "reading lice: $1"
            LICENSES="$LICENSES $1"
            ;;
    esac
    shift

done

flict -h >/dev/null 2>&1
if [ $? -ne 0 ] ;
then
    (echo "flict is missing" ; echo " - more info here: $FLICT_URL" )1>&2 ;
    exit 1;
fi

echo "Checking compat between $LICENSES"

flict $FLICT_ARGS -cc $LICENSES -of markdown | \
    pandoc --from=markdown --to=plain        | \
    awk '/^COMPATIBILITIES/,EOF {print $0;}' | \
    grep -v COMPATIBILITIES                  | \
    grep -v "^[ \t]*$"                       > \
    $TMP_FILE

export TMP_FILE
MUTUALS=$(cat $TMP_FILE | grep -e "<->")
ONE_WAYS=$(cat $TMP_FILE | grep -e "<-" -e "->" | grep -v -e "<->")
NO_WAYS=$(cat $TMP_FILE | grep -e "–//–")

if [ "$SHOW_MUTUAL" = "true" ] && [ "$MUTUALS" != "" ] 
then
    echo "Mutally compatible:"
    echo "$MUTUALS"
fi

if [ "$SHOW_ONE_WAY" = "true" ] && [ "$ONE_WAYS" != "" ] 
then
    echo "One way compatible:"
    echo "$ONE_WAYS"
fi

if [ "$SHOW_NON_COMPAT" = "true" ] && [ "$NO_WAYS" != "" ] 
then
    echo "Non compatible:"
    echo "$NO_WAYS"
fi

echo "--------------"
cat $TMP_FILE
rm $TMP_FILE
exit 0

echo "000000000000000000000000"
echo
    echo "Mutally compatible:"
    echo "$MUTUALS"
    echo "One way compatible:"
    echo "$ONE_WAYS"
    echo "Non compatible:"
    echo "$NO_WAYS"
    echo "file"
    
