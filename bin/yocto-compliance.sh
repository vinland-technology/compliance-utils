#!/bin/bash

###################################################################
#
# FOSS Compliance Utils / make-compliant.sh
#
# SPDX-FileCopyrightText: 2020 Henrik Sandklef
#
# SPDX-License-Identifier: GPL-3.0-or-later
#
###################################################################

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
        "--verbose" | "-v")
            VERBOSE=" -v "
            ;;
        "--list-artefacts" | "-la")
            LIST_ARTEFACTS="true"
            ;;
        *)
            # assume package
            if [ "$PACKAGE" = "" ]
            then
                PACKAGE="$1"
            else
                SPLIT_PACKAGE="$2"
            fi
    esac
    shift
done

OUT_DIR=compliance-results/$PACKAGE
GRAPH_OUT_DIR=${OUT_DIR}/graphs
LOG_FILE=${OUT_DIR}/$(basename $0).log
mkdir -p $OUT_DIR
mkdir -p $GRAPH_OUT_DIR

# tmp file
JSON_FILES=/tmp/ybtf-json-files.txt



exit_code_to_text()
{
    if [ $1 -eq 0 ]
    then
        echo OK
    else
        echo FAIL
    fi
}

#
# Create JSON
#
create_json()
{
    echo
    echo "Creating JSON for $PACKAGE ($PACKAGE_ARGS)"
    yocto-build-to-flict.sh ${YBTF_ARGS} ${PACKAGE_ARGS} | awk '/Created/,/^$/' | grep -v "Created" > ${JSON_FILES}
    if [ $? -ne 0 ]
    then
        echo "yocto-build-to-flict.sh ${YBTF_ARGS} ${PACKAGE_ARGS} failed"
        exit 1
    fi
    for jf in $(cat $JSON_FILES)
    do
        printf " * %-${FILE_FMT_LEN}s " "$(basename $jf):"
        echo "OK"
    done
    
    
}

#
# Verify JSON files
#
verify_json()
{
    echo
    echo "Verifying JSON files for $PACKAGE"
    ERR_CNT=0
    for jf in $(cat $JSON_FILES)
    do
        #    echo " * $jf"
        printf " * %-${FILE_FMT_LEN}s " "$(basename $jf):"
        jq '.' $jf >/dev/null 2>&1
        RET=$?
        if [ $RET -ne 0 ]
        then
            echo "jq '.' $jf failed "
            echo "... leaving"
            exit 2
        fi
        echo "OK"
    done
}   

#
# Create package graphs
#
create_graphs_helper()
{
    local DOT_FILE="$1"
    local FORMAT="$2"
    
    printf "   * %-${FILE_FMT_INDENT1_LEN}s " "$FORMAT:"
    dot -T${FORMAT} -O $DOT_FILE
    if [ $? -ne 0 ]
    then
        echo "dot -T${FORMAT} -O $DOT_FILE failed"
        exit 4
    fi
    echo "OK"
}
create_graphs()
{
    echo
    echo "Creating dot and graph files"
    for jf in $(cat $JSON_FILES)
    do
        jf_short=$(basename $jf)
        DOT_FILE=${GRAPH_OUT_DIR}/$jf_short.dot
        printf " * %-${FILE_FMT_LEN}s " "$(basename $DOT_FILE):"
        flict-to-dot.py $jf > $DOT_FILE
        if [ $? -ne 0 ]
        then
            echo "flict-to-dot.py $jf > ${GRAPH_OUT_DIR}/$(basename $jf).json failed"
            exit 3
        fi
        echo "OK"
        
        for fmt in pdf png svg
        do
            create_graphs_helper  $DOT_FILE $fmt
        done
    done
}


fix_json()
{
    JF=$1
    EXPR="$2"
#    echo "cat $jf | sed $SED_EXPR" 
    echo "cat $jf | $SED_EXPR" | bash 
}

#
# Fixing license expressions
#
fix_license_expressions()
{
    echo
    echo "Fixing license expressions in JSON files"
    JSON_FIXED_FILES=""
    for jf in $(cat $JSON_FILES)
    do
        jf_short=$(basename $jf)
        SPDX_TRANSLATION_FILE=./spdx-translation.json
        FIXED_JSON=${GRAPH_OUT_DIR}/$(basename $(echo $jf | sed 's,\.json,-fixed\.json,g'))
        printf " * %-${FILE_FMT_LEN}s " "$jf_short:"
        ~/opt/vinland/compliance-utils/bin/spdx-translations.py ${SPDX_TRANSLATION_FILE} $jf > $FIXED_JSON
        #fix_json $FIXED_JSON "$SED_EXPR"  > $FIXED_JSON
        RET=$?
        if [ $RET -ne 0 ]
        then
            echo "fix_json > $FIXED_JSON failed"
            exit 4
        fi
        echo "OK "
        
        JSON_FIXED_FILES="$JSON_FIXED_FILES $FIXED_JSON"
    done
}

#
# Dirty hacks done dirt cheap
#
dirty_hacks_done_dirt_cheap()
{
    echo
    echo "Fixing license expressions in a dirty way"
    echo " ---===  fixes are due to flict shortcomings THEY MUST BE REMOVED! ===---"
    for jf in $JSON_FIXED_FILES
    do
        printf " * %-${FILE_FMT_LEN}s %s" "$(basename $jf):"
        mv ${jf} ${jf}.tmp
        cat $jf.tmp |
            sed \
                -e 's,BSD-2,BSD-3,g' \
                -e 's,BSD-4,BSD-3,g' \
                -e 's,MIT-style,MIT,g' \
                > ${jf}
        RET=$?
        if [ $RET -ne 0 ]
        then
            echo "dirty fix of $jf failed"
            exit 4
        fi
        echo "OK "
    done
}

#
# Verify fixed JSON files
#
verified_fixed_json()
{
    echo
    echo "Verifying fixed JSON files for $PACKAGE"
    ERR_CNT=0
    for jf in $JSON_FIXED_FILES
    do
        #    echo " * $jf"
        printf " * %-${FILE_FMT_LEN}s " "$(basename $jf):"
        jq '.' $jf >/dev/null 2>&1
        RET=$?
        if [ $RET -ne 0 ]
        then
            echo "jq '.' $jf failed "
            echo "... leaving"
            exit 5
        fi
        echo "OK"
    done
}

#
# Check license compliance with flict
#
check_license_compliance()
{
    echo
    echo "Checking license compliance (flict)"
    return
    CUR_DIR=$(pwd)
    pushd ~/opt/vinland/flict/ # >/dev/null 2>&1
    for jf in  $JSON_FIXED_FILES
    do
        JSON=${CUR_DIR}/${jf}
        printf " * %-${FILE_FMT_LEN}s " "$(basename $jf):"
        echo        bin/flict -c $JSON | tail -100 | awk '/Metadata/,/^$/'  > ${PKG_OUT_DIR}/$PACKAGE-compliance-report.txt 
        RET=$?
        case $RET in 
            "0")
                echo "OK"
                ;;
            "1")
                echo OK "(avoided licenses only)"
                ;;
            "1")
                echo FAIL "(denied licenses only)"
                ;;
            *)
                echo "FAIL"
                ;;
        esac
    done
    popd  >/dev/null 2>&1
}


#
# Collect source code
#
collect_source_code()
{
    local FAILED_DIRS
    echo
    echo "Collecting source code"
    PKG_OUT_DIR=$(pwd)/${OUT_DIR}
    printf " * %-${FILE_FMT_LEN}s " "${PACKAGE}-${VERSION_SHORT}.zip:"
    VERSION_SHORT_TRIMMED=$(echo ${VERSION_SHORT} | sed 's,[0-9]*_,,g')
    local TRY_DIRS="${BUILD_DIR}/${PACKAGE}/${VERSION}/archiver-work  ${BUILD_DIR}/${PACKAGE}/${VERSION}/${PACKAGE}-${VERSION_SHORT}  ${BUILD_DIR}/${PACKAGE}/${VERSION}/${PACKAGE}-${VERSION_SHORT_TRIMMED}   ${BUILD_DIR}/${PACKAGE}/${VERSION}/${PACKAGE}-src   ${BUILD_DIR}/${PACKAGE}/${VERSION}/git   ${BUILD_DIR}/${PACKAGE}/packages-split/${PACAKAGE}-src/"
    for dir in $TRY_DIRS
    do
        pushd ${dir}  >/dev/null 2>&1
        RET=$?
        if [ $RET -eq 0 ]
        then
            : #echo "found a place: $dir"
            break
        fi
    done
    
    if [ $RET -ne 0 ]
    then
        echo "Could not enter source directory for $PACKAGE"
        echo "Tried: $TRY_DIRS"
        exit 1
    fi

    
    zip -r ${PKG_OUT_DIR}/${PACKAGE}-${VERSION_SHORT}.zip .  >/dev/null 2>&1
    if [ $? -ne 0 ]
    then
        echo "zip -r ${PKG_OUT_DIR}/${PACKAGE}-${VERSION_SHORT}.zip . failed"
        exit 1
    fi
    echo "OK"
    popd  >/dev/null 2>&1
}


#
# Collect license information
#
collect_license_information()
{
    echo
    echo "Collecting license information"
    printf " * %-${FILE_FMT_LEN}s " "${PACKAGE}-${VERSION_SHORT}-licenses.zip:" 
    pushd ${BUILD_DIR}/${PACKAGE}/${VERSION}/packages-split/${PACKAGE}-lic/usr/share/licenses/${PACKAGE}/  >/dev/null 2>&1
    if [ $? -ne 0 ]
    then
        echo "pushd ${BUILD_DIR}/${PACKAGE}/${VERSION}/packages-split/${PACKAGE}-lic/usr/share/licenses/${PACKAGE}/ failed"
        exit 1
    fi
    zip -r ${PKG_OUT_DIR}/${PACKAGE}-${VERSION_SHORT}-licenses.zip .  > /dev/null 2>&1
    if [ $? -ne 0 ]
    then
        echo "zip -r ${PKG_OUT_DIR}/${PACKAGE}-${VERSION_SHORT}-licenses.zip failed"
        exit 1
    fi
    echo "OK"
    popd  >/dev/null 2>&1
}


#
# Collect copyright information
#
collect_copyright_information()
{
    echo
    echo "Collecting copyright information - DUMMY IMPLEMENTATION"
    C_ZIP=${PKG_OUT_DIR}/${PACKAGE}-${VERSION_SHORT}-copyright.zip
    printf " * %-${FILE_FMT_LEN}s " "${C_ZIP}" 
    touch ${C_ZIP}
    echo "OK"
}

check_if_closed()
{
    LICENSES=$(grep "License:" ${BUILD_DIR}/${PACKAGE}/${VERSION}/${PACKAGE}.spec | sed 's,License:,,g' | tr '[A-Z]' '[a-z]')
    declare -A LICENSE_MAP
    for lic in $LICENSES
    do
        LICENSE_MAP[$lic]="exists"
    done
    LIC_CNT=${#LICENSE_MAP[@]}

    case $LIC_CNT in
        "0")
            echo "Panic in Detroit. No license found in ${PACKAGE}/${VERSION}/${PACKAGE}.spec"
            exit 1
            ;;
        "1")
            CLOSED=$(echo ${!LICENSE_MAP[@]} | grep -i closed | wc -l)
            if [ $CLOSED -eq 0 ]
            then
                echo "foss"
            else
                echo "closed"
            fi
            ;;
        *)
            CLOSED=$(echo ${!LICENSE_MAP[@]} | grep -i closed | wc -l)
#            echo "too many licenses??? (${!LICENSE_MAP[@]})"
            if [ $CLOSED -eq 0 ]
            then
                echo "foss"
            else
                echo "mix"
#                echo "mixed licenses: ${!LICENSE_MAP[@]}" 1>&2
            fi
            ;;
    esac
}

all()
{
    DONE_PLACEHOLDER=${PKG_OUT_DIR}/${PACKAGE}-${VERSION_SHORT}-done.placeholder
    if [ -f ${DONE_PLACEHOLDER} ]
    then
        echo "$(basename DONE_PLACEHOLDER) already present, ignoring ${PACKAGE}"
        return
    fi

    # TEMP
    C_ZIP=${PKG_OUT_DIR}/${PACKAGE}-${VERSION_SHORT}-copyright.zip
    if [ -f ${C_ZIP} ]
    then
        echo "$(basename C_ZIP) already present, ignoring ${PACKAGE}"
        return
    fi


    
    CLOSED_PLACEHOLDER=${PKG_OUT_DIR}/${PACKAGE}-${VERSION_SHORT}-closed-source.placeholder
    if [ -f ${CLOSED_PLACEHOLDER} ]
    then
        echo "${PACKAGE} already marked as closed source, ignoring"
        return
    fi
 
    
    LICENSE_INFO=$(check_if_closed)
#    echo "LICENSE_INFO: $LICENSE_INFO"
    case $LICENSE_INFO in
        "closed")
            echo "closed license, ignoring $PACKAGE"
            touch ${CLOSED_PLACEHOLDER}
            return
            ;;
        "mix")
            echo "mixed licenses, continuing"
            ;;
        "foss")
            ;;
    esac

    check_if_closed
    create_json
    verify_json
    create_graphs
    fix_license_expressions
    dirty_hacks_done_dirt_cheap
    verified_fixed_json
    check_license_compliance
    collect_source_code
    collect_license_information
    collect_copyright_information
    touch ${DONE_PLACEHOLDER}
}


if [ "${SPLIT_PACKAGE}" != "" ]
then
    PACKAGE_ARGS="$PACKAGE -sp $SPLIT_PACKAGE"
else
    PACKAGE_ARGS="$PACKAGE"    
fi

#if [ "$YBTF_ARGS" = "" ]
#then
#    YBTF_ARGS="-d 20201024110850  -m qemux86-64  -i core-image-minimal-qemux86-64"
#else
    YBTF_ARGS=" $VERBOSE -d $DATE  -m $MACHINE  -i $IMAGE -dd $DIST_DIR  -mtd ${META_TOP_DIR} "
#fi

if [ -z ${BUILD_DIR} ]
then
    BUILD_DIR=./tmp/work/$DIST_DIR
fi


FILE_FMT_LEN=60
FILE_FMT_INDENT1_LEN=$(( $FILE_FMT_LEN - 2 ))

VERSION=$(ls ${BUILD_DIR}/${PACKAGE}/ | head -1)
VERSION_SHORT=$(ls ${BUILD_DIR}/${PACKAGE}/ | head -1 | sed 's,\-r[0-9]*,,g')
PKG_OUT_DIR=$(pwd)/${OUT_DIR}

if [ "$LIST_ARTEFACTS" = "true" ]
then
    yocto-build-to-flict.sh ${YBTF_ARGS} -la
    exit $?
fi

if [ "$PACKAGE" = "" ]
then
    echo "Missing package name"
    exit 1
fi

set -o pipefail
all | tee $LOG_FILE 
RET=$?
exit $RET
