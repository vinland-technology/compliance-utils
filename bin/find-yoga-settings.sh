#!/bin/bash



IMAGE=$1

if [ "$IMAGE" = "" ]
then
    echo "Missing image name... Please try: "
    echo $0 apricot-image-ui
    exit 1
fi

find_machine()
{
    grep MACHINE conf/local.conf | cut -d "=" -f 2 | sed 's,[ \"]*,,g'
}

find_date()
{
    local MACHINE=$1
    local IMAGE=$2
    ls -1 tmp/deploy/licenses/ | grep $MACHINE | grep $IMAGE | rev | cut -d "-" -f 1 | rev
}

find_mtd()
{
    if [ $(find ../* -prune | grep -c meta) -gt 0 ]
    then
        echo ../
    elif [ $(find ../sources/* -prune | grep -c meta) -gt 0 ]
    then
        echo ../sources
    else
        echo "Can't find meta dir" 1>&2
        exit 1
    fi
}

find_image()
{
    local MACHINE=$1
    local IMAGE=$2
    ls -1 tmp/deploy/licenses/ | grep $MACHINE | grep $IMAGE | sed 's,\-[0-9]*$,,g'
}

find_dd()
{
    local BD=$1
    local MACHINE=$2

    find $BD/* -prune | grep -v "$(uname -m)-linux" | tr '\n' ' '
}

declare -A options

MACHINE=$(find_machine)

DATE=$(find_date $MACHINE $IMAGE)

MTD=$(find_mtd)

BD="tmp/work"

DD="$(find_dd $BD $MACHINE)"

#echo "IMAGE=$IMAGE"
#IMAGE=$(find_image $MACHINE $IMAGE)

echo "# yoga -d $DATE  -mtd $MTD -m $MACHINE -bd $DD -i $IMAGE-$MACHINE"

