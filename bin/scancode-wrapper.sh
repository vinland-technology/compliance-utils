#!/bin/bash

# FOSS Compliance Utils / scancode-wrapper.sh
#
# SPDX-FileCopyrightText: 2021 Henrik Sandklef
#
# SPDX-License-Identifier: GPL-3.0-or-later
#

#
# COmpliance tools image settings
#
DOCKER_IMAGE=sandklef/compliance-tools
DOCKER_TAG=0.1


COMPLIANCE_UTILS_VERSION=__COMPLIANCE_UTILS_VERSION__
if [ "${COMPLIANCE_UTILS_VERSION}" = "__COMPLIANCE_UTILS_VERSION__" ]
then
    GIT_DIR=$(dirname ${BASH_SOURCE[0]})
    COMPLIANCE_UTILS_VERSION=$(cd $GIT_DIR && git rev-parse --short HEAD)
fi


#
# internal vars
#
DEBUG=false
PARALLEL_ARGS=" -n $(cat /proc/cpuinfo | grep processor | wc -l) "
MYNAME=scancode-wrapper.sh

#
#
#
DOCKER_ARGS=" ${DOCKER_IMAGE}:${DOCKER_TAG}"
MOUNT_DIR=/compliance-tools
DOCKER_MOUNT_ARGS="-v $(pwd):${MOUNT_DIR}"



error()
{
    echo "$*" 1>&2
}

verbose()
{
    if [ "$DEBUG" = "true" ]
    then
        echo "$*" 1>&2
    fi
}

verbosen()
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
        error "ERROR..."
        if [ "$2" != "" ]
        then
            error "$2"
        fi
        exit $1
    fi
}

check_image()
{
    local image=$1
    local tag=$2
    verbosen  "Checking docker image $image ($tag): "
    
    PRESENT=$(docker images | grep -e "$image" | grep "${tag}" | wc -l)
    if [ $PRESENT -gt 0 ] 
    then
        verbose "OK, present"
    else
        verbose "Fail, missing"
        error "No docker image \"${DOCKER_IMAGE}:${DOCKER_TAG}\""
        exit 1
    fi
}

dload_image()
{
    local image=$1
    local tag=$2
    verbosen  "Downloading docker image $image ($tag): "
    
    docker pull "${image}:${tag}"
    if [ $? -eq 0 ] 
    then
        verbose "OK"
    else
        verbose "Fail, could not pull image"
        error "Could not pull docker image \"${DOCKER_IMAGE}:${DOCKER_TAG}\""
        exit 1
    fi
}

scan_dir()
{
    if [ "${DIR_TO_SCAN}" = "" ] || [ ! -d "${DIR_TO_SCAN}" ] || [ $(echo ${DIR_TO_SCAN} | grep "/" | wc -l) -ne 0 ]
    then
        error "\"${DIR_TO_SCAN}\" is either empty, not a directory or contains \"/\""
        exit 1
    fi

    SC_REPORT=${DIR_TO_SCAN}-scan.json

    CHOWN_COMMAND="bash -c "

    verbose "Scanning of ${DIR_TO_SCAN} "
    docker run --rm -i -t ${DOCKER_MOUNT_ARGS} ${DOCKER_ARGS} scancode -clipe ${PARALLEL_ARGS} --json ${SC_REPORT} ${DIR_TO_SCAN} 
    exit_if_error $? "Failed to execute: docker run --rm -i -t ${DOCKER_MOUNT_ARGS} ${DOCKER_ARGS} scancode -clipe ${PARALLEL_ARGS} --json ${SC_REPORT} ${DIR_TO_SCAN} " 

    verbose "Changing ownership of ${DIR_TO_SCAN} to local user"
    docker run --rm -i -t ${DOCKER_MOUNT_ARGS} ${DOCKER_ARGS} bash -c "chown \$(stat -c \"%u.%g\" ${DIR_TO_SCAN}) ${SC_REPORT}"
    exit_if_error $? 'Failed to execute: docker run --rm -i -t ${DOCKER_MOUNT_ARGS} ${DOCKER_ARGS} bash -c "chown \$(stat -c \"%u.%g\" ${DIR_TO_SCAN}) ${SC_REPORT}'

    verbose "Created ${SC_REPORT}"
}

scancode_version()
{
    verbose "Getting version information from Scancode"
    docker run --rm -i -t ${DOCKER_ARGS} scancode --version
    exit_if_error $? "Failed to execute: docker run --rm -i -t ${DOCKER_MOUNT_ARGS} ${DOCKER_ARGS} ./scancode --version"
}

usage()
{
    echo "NAME"
    echo ""
    echo "    ${MYNAME} - scan for copyright and license using scancode"
    echo ""
    echo
    echo "SYNOPSIS"
    echo
    echo "    ${MYNAME} [OPTION] <DIR>"
    echo ""
    echo ""
    echo "DESCRIPTION"
    echo ""
    echo ""
    echo ""
    echo "OPTIONS"
    echo ""
    echo "    -np, --no-parallel"
    echo "          do not use parallel processes when scanning. By default all"
    echo "          processors are used. This option is useful if you want to "
    echo "          keep scancode in the background"
    echo
    echo "    -v, --verbose"
    echo "          enable verbose printout"
    echo
    echo "    --version"
    echo "          output version information"
    echo
    echo "    pull"
    echo "          pull docker image with Scancode version: $DOCKER_TAG"
    echo "          Pulls $DOCKER_IMAGE from docker.io"
    echo
    echo "EXAMPLES"
    echo ""
    echo "    \$ $MYNAME src"
    echo "    Scans src and creates src-scan.json"
    echo
    echo "AUTHOR"
    echo ""
    echo "    Written by Henrik Sandklef"
    echo
    echo "    Please note that this is simply a wrapper around the great program"
    echo "    Scancode."
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
    echo "    Scancode https://github.com/nexB/scancode-toolkit"
    echo "    - this is indeed a great program"
    echo
}
   

while [ "$1" != "" ]
do
    case "$1" in
        "--verbose"|"-v")
            DEBUG=true
            ;;
        "--no-parallel"|"-np")
            PARALLEL_ARGS=" -n 1 "
            ;;
        "--help"|"-h")
            usage
            exit 0
            ;;
        "--scancode-version"|"-sv")
            scancode_version
            exit 0
            ;;
        "pull")
            dload_image ${DOCKER_IMAGE} ${DOCKER_TAG}
            exit 0
            ;;
        "version"|"--version")
            echo "Compliance Utils version: " $COMPLIANCE_UTILS_VERSION
            scancode_version
            exit 0
            ;;
        *)
            DIR_TO_SCAN=$1
            ;;
    esac
    shift
    
done

check_image ${DOCKER_IMAGE} ${DOCKER_TAG}

scan_dir
