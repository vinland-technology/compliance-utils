#!/bin/bash

###################################################################
#
# FOSS Compliance Utils / setup scripts
#
# SPDX-FileCopyrightText: 2020 Henrik Sandklef
#
# SPDX-License-Identifier: GPL-3.0-or-later
#
###################################################################

LIB_DIR=lib

exit_on_error()
{
    if [ "$1" != "0" ]
    then
        if [ "$2" != "" ]
        then
            echo "$2"
            echo "return value: $1"
            exit $1
        else
            echo "Failure"
            echo "return value: $1"
            exit $1
        fi
    fi
}

get_date()
{
    echo -n "$(date '+%Y-%m-%d %H:%M:%S')"
}

log()
{
    echo -n "["
    get_date
    echo "] $*"
}

log_to_file()
{
    if [ "$LOG_FILE" != "" ]
    then
        log "$*" >> $LOG_FILE
    fi           
}

determine_os()
{
    if [ "$(uname  | grep -ic linux)" != "0" ]
    then
        OS=linux
        if [ -f /etc/fedora-release ]
        then
            DIST=fedora
        elif [ -f /etc/redhat-release ]
        then
            DIST=redhat
        elif [ -f /etc/os-release ]
        then
            if [ "$( grep NAME /etc/os-release | grep -i -c ubuntu)" != "0" ]
            then
                DIST=ubuntu
            else
                DIST=debian
            fi
        else
            echo "UNSUPPORTED Linux distribution"
            exit 1
        fi
    elif [ "$(uname  | grep -ic darwin)" != "0" ]
    then
        OS=MacOS
        DIST=MacOS
    elif [ "$(uname  | grep -ic cygwin)" != "0" ]
    then
        OS=cygwin
        DIST=cygwin
    elif [ "$(uname  | grep -ic MINGW)" != "0" ]
    then
        echo "UNSUPPORTED OS, bash or ... well, something else"
        echo "Based on the output from the command uname"
        echo "we're guessing you're running \"Git Bash\""
        echo ""
        echo "This might be a very good and useful software, "
        echo "possibly better than cygwin when it comes to git"
        echo "but this is not something we support. "
        echo ""
        echo "Your software"
        echo " * OS:    $(uname)"
        echo " * bash:  $0"
        echo ""
        echo ""
        echo "WHAT TO DO NOW?"
        echo ""
        echo "Install cygwin? Use Ubuntu for Windows?"
        echo ""
        exit 1
    else
        echo "UNSUPPORTED OS, bash or ... well, something else"
        echo "Your software"
        echo " * OS:    $(uname)"
        echo " * bash:  $0"
        exit 1
    fi

}

determine_os


echo "Installing software for $OS / $DIST"
SETUP_DIR=$(dirname $(realpath $(which $0)) | sed 's,\/bin,,g')
$SETUP_DIR/setup-$OS-$DIST.sh


which flict >/dev/null 2>&1
if [ $? -ne 0 ]
then
    echo "Can't locate flict (FOSS License Compatibility Tool)"
    echo ""
    echo "If it is installed, make sure to put it on your PATH or else"
    echo "install flict following the instructions here:"
    echo " https://github.com/vinland-technology/flict"
fi
