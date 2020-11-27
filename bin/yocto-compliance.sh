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

# TODO: use jq with raw option to get rid of "

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
        "--out-dir" | "-od")
            OUTDIR="$2"
            ;;
        "--list-imagepackages" | "-la")
            LIST_IMAGEPACKAGES="true"
            ;;
        *)
            # assume package
            if [ "$PACKAGE" = "" ]
            then
                WANTED_PACKAGE="$1"
            fi
    esac
    shift
done

if [ "$OUT_DIR" = "" ]
then
    OUT_DIR=compliance-results/
fi

LOG_FILE=${OUT_DIR}/$(basename $0).log
ERR_FILE=${OUT_DIR}/$(basename $0).err
mkdir -p $OUT_DIR


IMAGEPACKAGES_JSON=${OUT_DIR}/imagepackage-list.json


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
# Create imagepackage JSON
#
create_imagepackage_json()
{
    inform0n "Creating imagepackages file ${IMAGEPACKAGES_JSON}: "
    if [ ! -f ${IMAGEPACKAGES_JSON} ]
    then
        yoda.py ${YBTF_ARGS} list > ${IMAGEPACKAGES_JSON}
        if [ $? -eq 0 ]
        then
            echo "OK"
        else
            echo "Fail"
            return
        fi
    else
        echo "OK (using existing)"
    fi
}


#
# Create JSON
#
create_json()
{
    inform2n "Creating component JSON: "
    local COMPONENT_JSON=${PERMANENT_OUT_DIR}/$PACKAGE/${PACKAGE}-component.json
    if [ ! -f ${COMPONENT_JSON} ]
    then
#        echo "yoda.py ${YBTF_ARGS} ${PACKAGE_ARGS} component"
        yoda.py ${YBTF_ARGS} ${PACKAGE_ARGS} exportpackage  > ${COMPONENT_JSON}
        if [ $? -ne 0 ]
        then
            inform0 "yoda.py ${YBTF_ARGS} ${PACKAGE_ARGS} component failed"
            return
        fi
        echo "OK"
    else
        echo "OK (using old)"
    fi
}


#
# Split package json in to separate ones 
#
split_package_json()
{
    inform2 "Splitting component file"
    PKG_JSON=${PERMANENT_OUT_DIR}/$PACKAGE/${PACKAGE}-component.json
    SUB_PKG_BASE=${PERMANENT_OUT_DIR}/$PACKAGE/${PACKAGE}-component
    LAST_INDEX=$(jq ".componentFiles | keys | .[]"  $PKG_JSON | tail -1)
    JSON_FILES=""
    for i in $(seq 0 $LAST_INDEX)
    do
        VALID=$(jq ".componentFiles[$i].component.valid" $PKG_JSON )
        NAME=$(jq ".componentFiles[$i].component.name" $PKG_JSON | sed 's,\",,g')
        inform3n "$NAME: "
        if [ "$VALID" != "false" ]
        then
            SUB_PKG_JSON=$SUB_PKG_BASE-$NAME.json
            #echo "$i  $NAME $SUB_PKG_JSON  ($VALID)"
            jq ".components[$i]"   $PKG_JSON > $SUB_PKG_JSON
            JSON_FILES="$JSON_FILES $SUB_PKG_JSON"
            echo OK
        else
            echo "invalid, ingored"
        fi
    done
}

#
# Verify JSON files
#
verify_json()
{
    inform2 "Verifying JSON files for $PACKAGE"
    ERR_CNT=0
    for jf in $JSON_FILES
    do
        #    echo " * $jf"
        inform3n "$(basename $jf): "
        #printf " * %-${FILE_FMT_LEN}s " "$(basename $jf):"
        jq '.' $jf >/dev/null 2>&1
        RET=$?
        if [ $RET -ne 0 ]
        then
            echo "Fail (jq '.' $jf failed)"
            return
        else
            echo "OK"            
        fi
    done
}   

#
# Create flict component files
#
create_flict_json()
{
    inform2n "Creating flict component JSON: "
    local COMPONENT_JSON=${PERMANENT_OUT_DIR}/$PACKAGE/${PACKAGE}-component.json
    if [ ! -f ${COMPONENT_JSON} ]
    then
        echo "Could not find $COMPONENT_JSON (for $PACKAGE)"
        return
    fi

    FLICT_COMPONENT_JSON=${PERMANENT_OUT_DIR}/$PACKAGE/${PACKAGE}-component-flict.json
    yoda2flict.py ${COMPONENT_JSON} > ${FLICT_COMPONENT_JSON} 
    if [ $? -ne 0 ]
    then
        echo "yoda2flict.sh ${COMPONENT_JSON} > ${FLICT_COMPONENT_JSON}  failed"
        return
    else
        echo "OK"
        FLICT_JSON_FILES="$FLICT_COMPONENT_JSON $FLICT_JSON_FILES"
    fi
}



#
# Create package graphs
#
create_graphs_helper()
{
    local DOT_FILE="$1"
    local FORMAT="$2"
    
    dot -T${FORMAT} -O $DOT_FILE
    if [ $? -ne 0 ]
    then
        echo "dot -T${FORMAT} -O $DOT_FILE failed"
        return
    fi
}


create_graphs()
{
    inform2 "Creating dot and graph files"
    RES=OK
    for jf in $FLICT_JSON_FILES
    do
        jf_short=$(basename $jf)
        inform3n "$jf_short: "
        DOT_FILE=${GRAPH_OUT_DIR}/$jf_short.dot
        #printf " * %-${FILE_FMT_LEN}s " "$(basename $DOT_FILE):"
        flict-to-dot.py $jf > $DOT_FILE
        if [ $? -ne 0 ]
        then
            echo "Fail (flict-to-dot.py $jf > ${GRAPH_OUT_DIR}/$(basename $jf).json)"
            RES=Fail
        else
            echo -n "OK ("
            for fmt in pdf png svg
            do
                echo -n " $fmt"
                create_graphs_helper  $DOT_FILE $fmt
            done
            echo ")"
        fi
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
    inform2 "Fixing license expressions in JSON files"
    JSON_FIXED_FILES=""
    RES=OK
    for jf in ${FLICT_COMPONENT_JSON}
    do
        jf_short=$(basename $jf)
        inform3n "$jf_short"
        SPDX_TRANSLATION_FILE=./spdx-translation.json
        FIXED_JSON=${PERMANENT_OUT_DIR}/${PACKAGE}/$(basename $(echo $jf | sed 's,\.json,-fixed\.json,g'))
        spdx-translations.py ${SPDX_TRANSLATION_FILE} $jf > $FIXED_JSON
        #echo "spdx-translations.py ${SPDX_TRANSLATION_FILE} $jf > $FIXED_JSON"
        #fix_json $FIXED_JSON "$SED_EXPR"  > $FIXED_JSON
        RET=$?
        if [ $RET -ne 0 ]
        then
            echo "Failed (spdx-translations.py ${SPDX_TRANSLATION_FILE} $jf > $FIXED_JSON)"
            RES=Fail
            # TODO: store failed files
        else
            echo "OK"
            JSON_FIXED_FILES="$JSON_FIXED_FILES $FIXED_JSON"
        fi
    done
}

#
# Dirty hacks done dirt cheap
#
dirty_hacks_done_dirt_cheap()
{
    inform2 "---===  DIRTY HACK (temporary)  ===---"
    inform2 "Fixing license expressions in a dirty way"
    for jf in $JSON_FIXED_FILES
    do
        inform3n "$(basename $jf): "
        #printf " * %-${FILE_FMT_LEN}s %s" "$(basename $jf):"
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
            echo "Failed"
        else
            echo "OK"
        fi
    done
}

#
# Verify fixed JSON files
#
verified_fixed_json()
{
    inform2 "Verifying fixed JSON files for $PACKAGE"
    for jf in $JSON_FIXED_FILES
    do
        inform3n "$(basename $jf): "
        #printf " * %-${FILE_FMT_LEN}s " "$(basename $jf):"
        jq '.' $jf >/dev/null 2>&1
        RET=$?
        if [ $RET -ne 0 ]
        then
            echo "Failed "
        else
            echo "OK"
        fi
    done
}

#
# Check license compliance with flict
#
check_license_compliance()
{
    inform2 "Checking license compliance (flict)"
    for jf in  $JSON_FIXED_FILES
    do
        inform3n "$(basename $jf) "
        JSON_REPORT=${PERMANENT_OUT_DIR}/$PACKAGE/$PACKAGE-compliance-report.json
        TXT_REPORT=${PERMANENT_OUT_DIR}/$PACKAGE/$PACKAGE-compliance.txt
        #printf " * %-${FILE_FMT_LEN}s " "$(basename $jf):"
        set -o pipefail
        ~/.local/bin/flict --json -c $jf | tail -1 | jq '.' > ${JSON_REPORT}
#        echo ~/.local/bin/flict --json -c $jf #| tail -1 | jq '.' > ${JSON_REPORT}
        RET=$?
        echo "$RET" > $TXT_REPORT
        flict_exit_code_to_string $RET
    done
}


#
# Collect source code
#
collect_source_code()
{
    RES=OK
    local FAILED_DIRS
    inform2 "Collecting source code"
    VERSION_SHORT_TRIMMED=$(echo ${VERSION_SHORT} | sed 's,[0-9]*_,,g')
    local TRY_DIRS="${BUILD_DIR}/${PACKAGE}/${VERSION}/archiver-work  ${BUILD_DIR}/${PACKAGE}/${VERSION}/${PACKAGE}-${VERSION_SHORT}  ${BUILD_DIR}/${PACKAGE}/${VERSION}/${PACKAGE}-${VERSION_SHORT_TRIMMED}   ${BUILD_DIR}/${PACKAGE}/${VERSION}/${PACKAGE}-src   ${BUILD_DIR}/${PACKAGE}/${VERSION}/git   ${BUILD_DIR}/${PACKAGE}/packages-split/${PACAKAGE}-src/"
    RES=Fail
    inform3n "Finding src directory: "
    for dir in $TRY_DIRS
    do
        pushd ${dir}  >/dev/null 2>&1
        RET=$?
        if [ $RET -eq 0 ]
        then
            : #echo "found a place: $dir"
            RES=OK
            break
        else
            popd  >/dev/null 2>&1
        fi
    done
    echo "$RES"
    sync
    if [ "$RES" != "OK" ]
    then
        return
    fi

    ZIP_FILE=${PERMANENT_OUT_DIR}/${PACKAGE}/${PACKAGE}-${VERSION_SHORT}-src.zip
    inform3n "Creating zip file: "
    zip -r  ${ZIP_FILE} .  >/dev/null 2>&1
    if [ $? -ne 0 ]
    then
        echo "Fail (zip -r ${ZIP_FILE} .)"
    else
        echo "OK"
    fi
    popd  >/dev/null 2>&1
}


#
# Collect license information
#
collect_license_copyright_information()
{
    inform2 "Collecting copyright and license information" 

    COP_LIC_DIR=${BUILD_DIR}/${PACKAGE}/${VERSION}/packages-split/${PACKAGE}-lic/usr/share/licenses/${PACKAGE}/
    inform3n "Entering license directory: " 
    pushd ${COP_LIC_DIR}  >/dev/null 2>&1
    if [ $? -ne 0 ]
    then
        echo "Fail (pushd ${COP_LIC_DIR})"
        popd
        return
    fi
    echo "OK"
    sync
    
    ZIP_FILE=${PERMANENT_OUT_DIR}/${PACKAGE}/${PACKAGE}-${VERSION_SHORT}-lic-cop.zip
    inform3n "Creating zip file: "
    zip -r ${ZIP_FILE} .  > /dev/null 2>&1
    if [ $? -ne 0 ]
    then
        echo "Fail (zip -r ${ZIP_FILE})"
    else
        echo "OK"
    fi
    popd  >/dev/null 2>&1
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

per_package()
{
    local PACKAGE=$1
    local SUB_PACKAGES=$2
    local VERSION=$3
    local VERSION_SHORT=$4
    
    GRAPH_OUT_DIR=${PERMANENT_OUT_DIR}/$PACKAGE/graphs
    mkdir -p $GRAPH_OUT_DIR

    inform2n "Checking if package already done: "
    DONE_PLACEHOLDER=${PERMANENT_OUT_DIR}/${PACKAGE}/${PACKAGE}-${VERSION_SHORT}-done.placeholder
    if [ -f ${DONE_PLACEHOLDER} ]
    then
        echo " done ($(basename $DONE_PLACEHOLDER) already present)"
        return
    fi
    echo "not done, continuing"
    sync
    
    inform2n "Checking if package already has been marked closed source: "
    CLOSED_PLACEHOLDER=${PERMANENT_OUT_DIR}/${PACKAGE}/${PACKAGE}-${VERSION_SHORT}-closed-source.placeholder
    if [ -f ${CLOSED_PLACEHOLDER} ]
    then
        echo "${PACKAGE} marked as closed source, ignoring"
        return
    fi
    echo "FOSS or mix, continuing"
    sync

    inform2n "Getting license type: "    
    LICENSE_INFO=$(check_if_closed)
    #echo "LICENSE_INFO: $LICENSE_INFO"
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
            echo "FOSS licenses only, continuing"
            ;;
    esac
    sync

#    check_if_closed

    create_json "$PACKAGE" "$SUB_PACKAGES" "$VERSION" "$VERSION_SHORT" 
    split_package_json "$PACKAGE" "$SUB_PACKAGES" "$VERSION" "$VERSION_SHORT" 
    verify_json "$PACKAGE" "$SUB_PACKAGES" "$VERSION" "$VERSION_SHORT" 

    FLICT_JSON_FILES=""
    create_flict_json "$PACKAGE" "$SUB_PACKAGES" "$VERSION" "$VERSION_SHORT" 
    
    create_graphs "$PACKAGE" "$SUB_PACKAGES" "$VERSION" "$VERSION_SHORT" 

    fix_license_expressions "$PACKAGE" "$SUB_PACKAGES" "$VERSION" "$VERSION_SHORT" 
    dirty_hacks_done_dirt_cheap "$PACKAGE" "$SUB_PACKAGES" "$VERSION" "$VERSION_SHORT" 
    verified_fixed_json "$PACKAGE" "$SUB_PACKAGES" "$VERSION" "$VERSION_SHORT" 
    check_license_compliance "$PACKAGE" "$SUB_PACKAGES" "$VERSION" "$VERSION_SHORT" 
    collect_source_code "$PACKAGE" "$SUB_PACKAGES" "$VERSION" "$VERSION_SHORT" 
    collect_license_copyright_information "$PACKAGE" "$SUB_PACKAGES" "$VERSION" "$VERSION_SHORT" 

    touch ${DONE_PLACEHOLDER}
}

flict_exit_code_to_string()
{
    local EXIT_CODE="$1"
    if [ "$EXIT_CODE" = "" ]
    then
        echo "unknown"
        return
    fi
    
    case "$EXIT_CODE" in
        "0")
            echo "OK"
            ;;
        "1")
            echo OK "(avoided licenses only)"
            ;;
        "2")
            echo FAIL "(denied licenses only)"
            ;;
        *)
            #            echo "FAIL ($EXIT_CODE)"
            echo "Check failed (unsupported license?)"
            ;;
    esac
}


license_from_type()
{
    if [ ! -f $2 ]
    then
        echo "unknown"
        return
    fi
    
    JSON_DATA=$(cat $2)

    local type=$1
    export TY=$type
#    echo "$type"
 #   echo "$2"
    # get number of list items for this type
    type_size=$(echo $JSON_DATA | jq ".outbound.$TY | length")
    #echo " * type: $TY  elements: $type_size"
    local COMP_LICENSE_EXPRESSION=""
    if [ "$type_size" != "" ] && [ $type_size -gt 0 ]
    then
        RANGE_END=$(( $type_size - 1 ))
        RANGE="$(seq 0 $RANGE_END)"
        # loop over the list item (arrays)
        for elem_index in $RANGE
        do
            #echo " * type: $TY  elements: $type_size  elem_index: $elem_index"
            export IDX=$elem_index
            LICENSE_EXPRESSION=""
            for lic in $(echo $JSON_DATA | jq -r ".outbound.$TY[$IDX][].spdx")
            do
                #echo "add \"$lic\""
                lic_url="<a href=\"https://spdx.org/licenses/$lic.html\">$lic</a>"
                if [ "$LICENSE_EXPRESSION" = "" ]
                then
                    LICENSE_EXPRESSION="$lic_url"
                else
                    LICENSE_EXPRESSION="${LICENSE_EXPRESSION} & ${lic_url}"
                fi
            done
    #        echo "$type: \"$LICENSE_EXPRESSION\""
            if [ "$COMP_LICENSE_EXPRESSION" = "" ]
            then
                COMP_LICENSE_EXPRESSION="$LICENSE_EXPRESSION"
            else
                COMP_LICENSE_EXPRESSION="${COMP_LICENSE_EXPRESSION} | ${LICENSE_EXPRESSION}"
            fi
        done
    fi
    echo "$COMP_LICENSE_EXPRESSION"
}


top_html()
{
    echo "$*" >> ${PERMANENT_OUT_DIR}/yocto-compliance.html
}

create_new_top_html()
{
    rm    ${PERMANENT_OUT_DIR}/yocto-compliance.html
    touch ${PERMANENT_OUT_DIR}/yocto-compliance.html
}

create_package_html()
{
    local PACKAGE=$1
    local SUB_PACKAGES=$2
    local VERSION=$3
    local VERSION_SHORT=$4

    # gather license
    local DECLARED_LICENSE="unknown"
    FLICT_FIXED_JSON=./compliance-results/$PACKAGE/$PACKAGE-component-flict-fixed.json
    if [ -f  ${FLICT_FIXED_JSON} ]
    then
        DECLARED_LICENSE=$(jq -r '.component.license' ${FLICT_FIXED_JSON})
    fi

    # gather flict information
    if [ -f ${PERMANENT_OUT_DIR}/${PACKAGE}/${PACKAGE}-compliance.txt ]
    then
        COMPLIANCE_EXIT_CODE=$(cat ${PERMANENT_OUT_DIR}/${PACKAGE}/${PACKAGE}-compliance.txt)
        FLICT_MSG=$(flict_exit_code_to_string $COMPLIANCE_EXIT_CODE)
    else
        FLICT_MSG=unknown
    fi
    # gather flict compliance info
    JSON_REPORT=${PERMANENT_OUT_DIR}/${PACKAGE}/${PACKAGE}-compliance-report.json
    allowed_lic=$(license_from_type allowed $JSON_REPORT)
    avoid_lic=$(license_from_type avoid $JSON_REPORT)
    denied_lic=$(license_from_type denied $JSON_REPORT)

    top_html "    <div class=\"rTableRow\">"
    top_html "      <div class=\"rTableCell\">$PACKAGE</div>"
    top_html "      <div class=\"rTableCell\">$VERSION</div>"
    top_html "      <div class=\"rTableCell\">$DECLARED_LICENSE</div>"
    top_html "      <div class=\"rTableCell\">$FLICT_MSG</div>"
    top_html "      <div class=\"rTableCell\">$allowed_lic</div>"
    top_html "      <div class=\"rTableCell\">$avoid_lic</div>"
    top_html "      <div class=\"rTableCell\">$denied_lic</div>"
    top_html "    </div>"
}

create_top_page_html()
{
    local PACKAGE=$1
    local SUB_PACKAGES=$2
    local VERSION=$3
    local VERSION_SHORT=$4
   
    inform0 "Creating html page"

    create_new_top_html
    
    top_html "<html>"
    top_html "  <head> "
    top_html "    <link rel=\"stylesheet\" href=\"yocto-compliance.css\">"
    top_html "  </head>"
    top_html "  <body>"
    top_html "  <h1>Yocto build compliance</h1>"
    top_html "  <h2>Summary</h2>"
    top_html "  <h3>${#PACKAGES[@]} packages</h3>"
    top_html "  <ul>"

    FLICT_OK=$(grep "0" compliance-results/*/*-compliance.txt | wc -l)
    top_html "    <li>${FLICT_OK} OK </li>"

    FLICT_OK_AVOID=$(grep "1" compliance-results/*/*-compliance.txt | wc -l)
    top_html "    <li>${FLICT_OK_AVOID} OK (with avoid licenses)</li>"

    FLICT_OK_DENIED=$(grep "2" compliance-results/*/*-compliance.txt | wc -l)
    top_html "    <li>${FLICT_OK_DENIED} OK (with denied licenses)</li>"

    FLICT_UNKOWN=$(egrep "[3-9][0-9]*" compliance-results/*/*-compliance.txt | wc -l)
    top_html "    <li>${FLICT_UNKOWN} with unknown state (probably closed)</li>"

    MISSING_FILE=$(for d in $(find compliance-results/* -prune -type d ); do dir=$(basename $d); if [ ! -f compliance-results/$dir/$dir-compliance.txt ]; then echo $dir ; fi ; done | wc -l)

    top_html "    <li>${MISSING_FILE} with missing report (unsupported license, only contains script, text, configuration)</li>"    
    top_html "  </ul>"
    top_html "<h2>Packages</h2>"
    top_html "  <div class=\"rTable\">"
    top_html "    <div class=\"rTableRow\">"
    top_html "      <div class=\"rTableHead\"><strong>Package</strong></div>"
    top_html "      <div class=\"rTableHead\"><strong>Version</strong></div>"
    top_html "      <div class=\"rTableHead\"><strong>License</strong></div>"
    top_html "      <div class=\"rTableHead\"><strong>Compliant</strong></div>"
    top_html "      <div class=\"rTableHead\"><strong>Allowed outbound</strong></div>"
    top_html "      <div class=\"rTableHead\"><strong>Avoided outbound</strong></div>"
    top_html "      <div class=\"rTableHead\"><strong>Denied outbound</strong></div>"
    top_html "    </div>"
    for PACKAGE_ in "${!PACKAGES[@]}"
    do
        echo $PACKAGE_
    done | sort | while read PACKAGE
    do
        #    echo "PACKAGE: $PACKAGE (\"$WANTED_PACKAGE\")"
        SUB_PACKAGES=${PACKAGES[$PACKAGE]}
        SP_COUNT=$(( $( echo ${PACKAGES[$PACKAGE]} | grep -o ":" | wc -l) + 1 ))
        VERSION=${VERSIONS[$PACKAGE]}
        VERSION_SHORT=${VERSIONS_SHORT[$PACKAGE]}
        inform1n "$PACKAGE ($VERSION_SHORT)"
        create_package_html  "$PACKAGE" "$SUB_PACKAGES" "$VERSION" "$VERSION_SHORT" 
        echo "OK"
    done
    top_html "  </div>"
    top_html "</table>"
    top_html "</body></html>"

    cp yocto-compliance.css ${PERMANENT_OUT_DIR}/
}

create_top_page()
{
    local PACKAGE=$1
    local SUB_PACKAGES=$2
    local VERSION=$3
    local VERSION_SHORT=$4
    create_top_page_html     "$PACKAGE" "$SUB_PACKAGES" "$VERSION" "$VERSION_SHORT" 
}


YBTF_ARGS=" $VERBOSE -d $DATE  -m $MACHINE  -i $IMAGE -dd $DIST_DIR  -mtd ${META_TOP_DIR} "

if [ -z ${BUILD_DIR} ]
then
    BUILD_DIR=./tmp/work/$DIST_DIR
fi


FILE_FMT_LEN=70
FILE_FMT_INDENT1_LEN=$(( $FILE_FMT_LEN - 3 ))
FILE_FMT_INDENT2_LEN=$(( $FILE_FMT_LEN - 6 ))
FILE_FMT_INDENT3_LEN=$(( $FILE_FMT_LEN - 9 ))

verbose()
{
    echo "$*" 1>&2
}

inform0()
{
    printf "%-${FILE_FMT_LEN}s\n" "$*"  
}

inform0n()
{
    printf "%-${FILE_FMT_LEN}s" "$*"  
    sync
}

inform1()
{
    printf " * %-${FILE_FMT_INDENT1_LEN}s\n" "$*" 
}

inform1n()
{
    printf " * %-${FILE_FMT_INDENT1_LEN}s" "$*"  
    sync
}

inform2()
{
    printf "    * %-${FILE_FMT_INDENT2_LEN}s\n" "$*" 
}

inform2n()
{
    printf "    * %-${FILE_FMT_INDENT2_LEN}s" "$*"
    sync
}

inform3()
{
    printf "       * %-${FILE_FMT_INDENT3_LEN}s\n" "$*" 
}

inform3n()
{
    printf "       * %-${FILE_FMT_INDENT3_LEN}s" "$*"  
    sync
}

error()
{
    echo "$*" 1>&2
}







#
# MAIN
#

#VERSION=$(ls ${BUILD_DIR}/${PACKAGE}/ | head -1)
#VERSION_SHORT=$(ls ${BUILD_DIR}/${PACKAGE}/ | head -1 | sed 's,\-r[0-9]*,,g')
PERMANENT_OUT_DIR=$(pwd)/${OUT_DIR}
LOG_FILE=${PERMANENT_OUT_DIR}/$(basename $0 | sed 's,\.sh,\.log,g')

# This is needed for what ever we do
create_imagepackage_json 2>${ERR_FILE}

if [ "$LIST_IMAGEPACKAGES" = "true" ]
then
    echo "Listing imagepackage"
    jq '.imagepackages[].name' ${IMAGEPACKAGES_JSON} | sed 's,\",,g' | sort
    exit $?
fi


#create_imagepackage_json | tee ${LOG_FILE}
declare -A PACKAGES
declare -A VERSIONS
declare -A VERSIONS_SHORT
inform0n "Extracting information about packages (in imagepackage list): "
for line in $(jq '.imagepackages[] | "\(.package):\(.subPackage):\(.valid):\(.name):\(.packageVersion):\(.packageVersionDir)"' ${IMAGEPACKAGES_JSON} | sed 's,\",,g' | sort)
do
    VALID=$(echo $line | cut -d : -f 3)
    if [ "$VALID" = "true" ]
    then
        PACKAGE=$(echo $line | cut -d : -f 1)
        SUB_PACKAGE=$(echo $line | cut -d : -f 2)
        if [ "${PACKAGES[$PACKAGE]}" = "" ]
        then
            VERSION_SHORT=$(echo $line | cut -d : -f 5)
            VERSION=$(echo $line | cut -d : -f 6)
            PACKAGES[$PACKAGE]="$SUB_PACKAGE"
            VERSIONS[$PACKAGE]="$VERSION"
            VERSIONS_SHORT[$PACKAGE]="$VERSION_SHORT"
        else
            PACKAGES[$PACKAGE]="${PACKAGES[$PACKAGE]}:$SUB_PACKAGE"
        fi
    else
        # TODO: manage/present the ones that we could not handle
        NAME=$(echo $line | cut -d : -f 4)
        #echo "ERROR: $NAME ($line)"
    fi    
done
inform0 "OK"

if [ "$WANTED_PACKAGE" = "" ]
then
    inform0 "Listing all packages"
else
    inform0 "Listing single package $WANTED_PACKAGE"
fi

for PACKAGE in "${!PACKAGES[@]}"
do
#    echo "PACKAGE: $PACKAGE (\"$WANTED_PACKAGE\")"
    if [ "$WANTED_PACKAGE" = "" ] || [ "$WANTED_PACKAGE" = "$PACKAGE" ] 
    then
        SUB_PACKAGES=${PACKAGES[$PACKAGE]}
        SP_COUNT=$(( $( echo ${PACKAGES[$PACKAGE]} | grep -o ":" | wc -l) + 1 ))
        inform1 "$PACKAGE / $SP_COUNT sub packages"
        PACKAGE_ARGS=" -p $PACKAGE -sp $SUB_PACKAGES "
        #    echo "$VERSION | $VERSION_SHORT"
        VERSION=${VERSIONS[$PACKAGE]}
        VERSION_SHORT=${VERSIONS_SHORT[$PACKAGE]}
        per_package "$PACKAGE" "$SUB_PACKAGES" "$VERSION" "$VERSION_SHORT" 
    fi
done 2>>${ERR_FILE} | tee -a ${LOG_FILE} 

if [ "$WANTED_PACKAGE" = "" ] 
then
    create_top_page  | tee -a ${LOG_FILE} 
fi

echo done
#set -o pipefail
#all | tee $LOG_FILE 
#RET=$?
#exit $RET
