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

#echo "TMP_FILE: $TMP_FILE"

SHOW_MUTUAL=false
SHOW_ONE_WAY=false
SHOW_NON_COMPAT=true

REGEXP=""
FLICT_ARGS=""

while [ "$1" != "" ]
do
    case "$1" in
        "-nr"|"--no-relicense")
            FLICT_ARGS="$FLICT_ARGS -nr"
            ;;
        *)
            #echo "reading lice: $1"
            LICENSES="$LICENSES $1"
            ;;
    esac
    shift

done

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
    cat $TMP_FILE
    
