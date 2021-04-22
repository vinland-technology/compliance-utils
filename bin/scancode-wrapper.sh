#!/bin/bash

# FOSS Compliance Utils / scancode-wrapper.sh
#
# SPDX-FileCopyrightText: 2021 Henrik Sandklef
#
# SPDX-License-Identifier: GPL-3.0-or-later
#


#
# Scancode docker image settings
#
SC_IMAGE=sandklef/sandklef-scancode
SC_TAG=21.3.31

#
# internal vars
#
DEBUG=false

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
        error "No docker image \"${SC_IMAGE}:${SC_TAG}\""
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
        error "Could not pull docker image \"${SC_IMAGE}:${SC_TAG}\""
        exit 1
    fi
}

while [ "$1" != "" ]
do
    case "$1" in
        "--verbose"|"-v")
            DEBUG=true
            ;;
        "pull")
            dload_image ${SC_IMAGE} ${SC_TAG}
            exit 0
            ;;
        *)
            DIR_TO_SCAN=$1
            ;;
    esac
    shift
            
done

check_image ${SC_IMAGE} ${SC_TAG}

if [ "${DIR_TO_SCAN}" = "" ] || [ ! -d "${DIR_TO_SCAN}" ] || [ $(echo ${DIR_TO_SCAN} | grep "/" | wc -l) -ne 0 ]
then
    error "\"${DIR_TO_SCAN}\" is either empty, not a directory or contains \"/\""
    exit 1
fi

SC_REPORT=${DIR_TO_SCAN}-scan.json
MOUNT_DIR=/tmp

DOCKER_MOUNT_ARGS="-v $(pwd):${MOUNT_DIR}"
DOCKER_ARGS=" ${SC_IMAGE}:${SC_TAG}"

CHOWN_COMMAND="bash -c "

verbose "Scanning of ${DIR_TO_SCAN} "
docker run --rm -i -t ${DOCKER_MOUNT_ARGS} ${DOCKER_ARGS} ./scancode -clipe --json /tmp/${SC_REPORT} ${MOUNT_DIR}/${DIR_TO_SCAN} 
exit_if_error $? "Failed to execute: docker run --rm -i -t ${DOCKER_MOUNT_ARGS} ${DOCKER_ARGS} ./scancode -clipe --json /tmp/${SC_REPORT} ${MOUNT_DIR}/${DIR_TO_SCAN} " 

verbose "Changing ownership of ${DIR_TO_SCAN} to local user"
docker run --rm -i -t ${DOCKER_MOUNT_ARGS} ${DOCKER_ARGS} bash -c "chown \$(stat -c \"%u.%g\" ${MOUNT_DIR}/${DIR_TO_SCAN}) ${MOUNT_DIR}/${SC_REPORT}"
exit_if_error $? 'Failed to execute: docker run --rm -i -t ${DOCKER_MOUNT_ARGS} ${DOCKER_ARGS} bash -c "chown \$(stat -c \"%u.%g\" ${MOUNT_DIR}/${DIR_TO_SCAN}) ${MOUNT_DIR}/${SC_REPORT}'

verbose "Created ${SC_REPORT}"
