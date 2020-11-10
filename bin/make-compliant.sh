#!/bin/bash

PACKAGE="$1"
SPLIT_PACKAGE="$2"
OUT_DIR=test-results/$PACKAGE
GRAPH_OUT_DIR=test-results/$PACKAGE/graphs
LOG_FILE=${OUT_DIR}/$(basename $0).log
mkdir -p $OUT_DIR
mkdir -p $GRAPH_OUT_DIR

# tmp file
JSON_FILES=/tmp/ybtf-json-files.txt

if [ "$PACKAGE" = "" ]
then
    echo "Missing package name"
    exit 1
fi


if [ "${SPLIT_PACKAGE}" != "" ]
then
    PACKAGE_ARGS="$PACKAGE -sp $SPLIT_PACKAGE"
else
    PACKAGE_ARGS="$PACKAGE"    
fi


YBTF_ARGS="-d 20201024110850  -m qemux86-64  -i core-image-minimal-qemux86-64"
TMP_DIR=tmp/work/core2-64-poky-linux

FILE_FMT_LEN=60
FILE_FMT_INDENT1_LEN=$(( $FILE_FMT_LEN - 2 ))

VERSION=$(ls ${TMP_DIR}/${PACKAGE}/ | head -1)
VERSION_SHORT=$(ls ${TMP_DIR}/${PACKAGE}/ | head -1 | sed 's,\-r[0-9]*,,g')
PKG_OUT_DIR=$(pwd)/${OUT_DIR}


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
    for jf in  $JSON_FIXED_FILES
    do
        JSON=$(pwd)/${jf}
        printf " * %-${FILE_FMT_LEN}s " "$(basename $jf):"
        cd ~/opt/vinland/flict-osadl/ >/dev/null 2>&1
        bin/flict -c $JSON | tail -100 | awk '/Metadata/,/^$/'  > ${PKG_OUT_DIR}/$PACKAGE-compliance-report.txt 
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
        cd -  >/dev/null 2>&1
    done
}


#
# Collect source code
#
collect_source_code()
{
    echo
    echo "Collecting source code"
    PKG_OUT_DIR=$(pwd)/${OUT_DIR}
    printf " * %-${FILE_FMT_LEN}s " "${PACKAGE}-${VERSION_SHORT}.zip:" 
    cd ${TMP_DIR}/${PACKAGE}/${VERSION}/${PACKAGE}-${VERSION_SHORT}  >/dev/null 2>&1
    if [ $? -ne 0 ]
    then
        echo "cd ${TMP_DIR}/${PACKAGE}/${VERSION}/${PACKAGE}-${VERSION_SHORT} failed"
        exit 1
    fi
    zip -r ${PKG_OUT_DIR}/${PACKAGE}-${VERSION_SHORT}.zip .  >/dev/null 2>&1
    if [ $? -ne 0 ]
    then
        echo "zip -r ${PKG_OUT_DIR}/${PACKAGE}-${VERSION_SHORT}.zip . failed"
        exit 1
    fi
    echo "OK"
    cd -  >/dev/null 2>&1
}


#
# Collect license information
#
collect_license_information()
{
    echo
    echo "Collecting license information"
    printf " * %-${FILE_FMT_LEN}s " "${PACKAGE}-${VERSION_SHORT}-licenses.zip:" 
    cd ${TMP_DIR}/${PACKAGE}/${VERSION}/packages-split/${PACKAGE}-lic/usr/share/licenses/${PACKAGE}/  >/dev/null 2>&1
    if [ $? -ne 0 ]
    then
        echo "cd ${TMP_DIR}/${PACKAGE}/${VERSION}/packages-split/${PACKAGE}-lic/usr/share/licenses/${PACKAGE}/ failed"
        exit 1
    fi
    zip -r ${PKG_OUT_DIR}/${PACKAGE}-${VERSION_SHORT}-licenses.zip .  > /dev/null 2>&1
    if [ $? -ne 0 ]
    then
        echo "zip -r ${PKG_OUT_DIR}/${PACKAGE}-${VERSION_SHORT}-licenses.zip failed"
        exit 1
    fi
    echo "OK"
    cd -  >/dev/null 2>&1
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

all()
{

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
}



all | tee $LOG_FILE
