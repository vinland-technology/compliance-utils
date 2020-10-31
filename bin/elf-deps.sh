#!/bin/bash

# SPDX-FileCopyrightText: 2020 Henrik Sandklef
#
# SPDX-License-Identifier: GPL-3.0-or-later


#
#
# find dependencies recursively for an ELF program/library 
#
#

OUTPUT_DIR=~/.vinland/elf-deps
FORMAT=txt
EXCLUDE_LIBC_STUFF="-e libm.so -e libdl.so -e libc.so -e librt.so -e libpthread.so -e ld-linux -e libresolv -e libgcc_s"

PROG=$(basename $0)

DEFAULT_LIB_DIRS="/lib /usr/lib64 /usr/lib"

err()
{
    echo "$*" 1>&2
}

inform()
{
    echo "$*" 1>&2
}

list_dep()
{
    readelf -d $1 | \
        grep NEEDED | \
        grep -v $EXCLUDE_LIBC_STUFF | \
        cut -d ":" -f 2 | \
        sed -e 's,\[,,g' -e 's,],,g' -e 's,[ ]*,,g';
}

findlib()
{
    LIB=$1
#    err "check path for $1"
    if [[ "$LIB" =~ ^/ ]] || [[ "$LIB" =~ ^./ ]]
    then
 #       err " - use as is $1"
        echo $LIB
    else
  #      err " - find $1"
        find $LIB_DIRS -name "${LIB}*" -type f | head -1
    fi
}

list_deps()
{
    local LIB=$1
    local INDENT="$2"
    local LIB_PATH=$(findlib $LIB)

    if [ "$FORMAT" = "txt" ]
    then
       echo "$INDENT$LIB"
    fi

    local lib
    for lib in $(list_dep $LIB_PATH)
    do

        case "$FORMAT" in
            "txt")
                list_deps "${lib}" "${INDENT}  "
                ;;
            "dot")
                echo "\"$(basename $LIB)\" -> \"$lib\""
                list_deps "${lib}" "${INDENT}  "
                ;;
            *)
                echo "Unsupported format ($FORMAT)"
                exit 4
                ;;
        esac
    done
}


list_prog_deps()
{
    local PROG=$1
    local INDENT="$2"
    if [[ "$PROG" =~ ^#.*  ]] ||  [[ "$PROG" =~ ^#/*  ]]
    then
        :
    else
        PROG=$(which $PROG)
    fi
    if [ "$FORMAT" = "txt" ]
    then
       echo "$INDENT$LIB"
    fi

    local lib
    for lib in $(list_dep $PROG)
    do
        case "$FORMAT" in
            "txt")
                list_deps "${lib}" "${INDENT}  "
                ;;
            "dot")
                echo "\"$PROG\" -> \"$lib\""
                list_deps "${lib}" "${INDENT}  "
                ;;
            *)
                echo "Unsupported format ($FORMAT)"
                exit 4
                ;;
        esac
    done
}

usage()
{
    echo "NAME"
    echo "   $PROG - list dependencies recursively"
    echo
    echo "SYNOPSIS"
    echo "   $PROG [OPTIONS] FILE"
    echo
    echo "DESCRIPTION"
    echo "   List dependencies recursively foe the given file. The files can be"
    echo "   either a program (name of with path) or a library (name or with path)"
    echo "   If the supplied file does not have path we do our best trying to find it"
    echo "   using which or (internal function) findllib."
    echo 
    echo "   The file must be in ELF format"
    echo
    echo "OPTIONS"
    echo "   -od, --outdir DIR"
    echo "        output logs to DIR. Default is ~/.vinland/elf-deps"
    echo
    echo "   -l, --log"
    echo "        store log in outpur dir, as well as print to stdout"
    echo
    echo "   -s, --silent"
    echo "        do not print to stdout"
    echo
    echo "   --lib-dir DIR"
    echo "        adds DIR to directories to search for libraries. For every use of this option"
    echo "        the directories are added. If no directory is specified the default directories"
    echo "        are: $DEFAULT_LIB_DIRS"
    echo
    echo "   Format options"
    echo "   --dot"
    echo "        create dot like file (in output dir). Autmatically adds: \"-s\" and \"-l\" "
    echo
    echo "   --pdf"
    echo "        create pdf file (in output dir). Autmatically adds: \"-s\" and \"-l\" "
    echo
    echo "   --png"
    echo "        create png file (in output dir). Autmatically adds: \"-s\" and \"-l\" "
    echo
    echo "   --svg"
    echo "        create svg file (in output dir). Autmatically adds: \"-s\" and \"-l\" "
    echo
    echo "   --png"
    echo "        create pdf file (in output dir). Autmatically adds: \"-s\" and \"-l\" "
    echo
    echo "EXAMPLES"
    echo "   $PROG evince"
    echo "        lists all dependencies for the program evince"
    echo
    echo "   $PROG --pdf libcairo2.so"
    echo "        lists all dependencies for the library libcairo2.so and creates report in pdf format"
    echo
    echo "EXIT CODES"
    echo "    0 success"
    echo "    1 could not find file"
    echo "    2 file not in ELF format"
    echo "    3 silent and no logging not vailed"
    echo "    4 unknown or unsupported format  "
    echo
    echo "AUTHOR"
    echo "    Written by Henrik Sandklef"
    echo
    echo "REPORTING BUGS"
    echo "    Add an issue at https://github.com/vinland-technology/compliance-utils"
    echo
    echo "COPYRIGHT & LICENSE"
    echo "   Copyright 2020 Henrik Sandklef"
    echo "   License GPL-3.0-or-later"
}

find_dependencies()
{
    IS_PROGRAM=0
    FILE=$1
    
    if [ ! -f $FILE ]
    then
        # If file can NOT be found directly
        # Try if which can find it
        which $FILE >/dev/null 2>&1
        if [ $? -eq 0 ]
        then
            # which could find it
            FILE=$(which $FILE)
        else
            if [[ "$FILE" =~ ^#.*  ]] ||  [[ "$FILE" =~ ^#/*  ]]
            then
                :
            else
#                echo "FIND LIB FOR $FILE: $(findlib $FILE)"
                FILE=$(findlib $FILE)
            fi
        fi
    fi

    
    if [ "$FILE" = "" ]
    then
        err "Could not find where $1 is located"
        err ".. try again including path"
        exit 1
    fi

    # Check if program or library is in ELF format
    IS_ELF=$(file $FILE | grep -c ":[ ]*ELF")

    if [ $IS_ELF -eq 0 ]
    then
        err "File \"$FILE\" is not in ELF format"
        exit 2
    fi

    # Check if it's a program or library
    IS_PROGRAM=$(file $FILE | grep -c interpreter)

    if [ $IS_PROGRAM -eq 0 ]
    then
        list_deps $FILE ""
    else
        list_prog_deps $FILE ""
    fi

}


while [ "$1" != "" ]
do
    case "$1" in
        "--help"| "-h")
            usage
            exit
            ;;
        "--outdir"| "-od")
            OUTPUT_DIR=$2
            shift
            ;;
        "--log"| "-l")
            LOG=true
            ;;
        "--silent"| "-s")
            SILENT=true
            ;;
        "--dot")
            FORMAT=dot
            LOG=true            
            SILENT=true
            ;;
        "--pdf")
            FORMAT=dot
            DOT_FORMATS="$DOT_FORMATS pdf"
            SILENT=true
            LOG=true
            ;;
        "--svg")
            FORMAT=dot
            DOT_FORMATS="$DOT_FORMATS svg"
            SILENT=true
            LOG=true
            ;;
        "--jpg")
            FORMAT=dot
            DOT_FORMATS="$DOT_FORMATS svg"
            SILENT=true
            LOG=true
            ;;
        "--png")
            FORMAT=dot
            DOT_FORMATS="$DOT_FORMATS png"
            SILENT=true
            LOG=true
            ;;
        "--lib-dir")
            LIB_DIRS="$LIB_DIRS $2"
            shift
            ;;
        *)
            FILE=$1
            ;;
    esac
    shift
done

if [ "$LIB_DIRS" = "" ]
then
    LIB_DIRS=$DEFAULT_LIB_DIRS
fi

if [ "$LOG" = "true" ]
then
    LOG_FILE=${OUTPUT_DIR}/$(basename $FILE).log
    if [ "$SILENT" = "true" ]
    then
        mkdir -p ${OUTPUT_DIR}
        find_dependencies $FILE > $LOG_FILE
        inform "Log file created: $LOG_FILE"
    else
        find_dependencies $FILE | tee $LOG_FILE
        inform "Log file created: $LOG_FILE"
    fi

    DOT_FILE=${OUTPUT_DIR}/$(basename $FILE).dot
    printf "digraph depends {\n node [shape=plaintext]\n" > $DOT_FILE
    cat $LOG_FILE | sort -u >> $DOT_FILE
    printf "}" >> $DOT_FILE
    inform "Created dot file: $DOT_FILE"
    
    for fmt in $DOT_FORMATS
    do        
        OUT_FILE=${DOT_FILE}.$fmt
        dot -O -T$fmt ${DOT_FILE}
        inform "Created $fmt file: $OUT_FILE"
    done
else
    if [ "$SILENT" = "true" ]
    then
        err "It does not make sense to use silent mode and NOT log"
        exit 3
    else
        find_dependencies $FILE
    fi
fi
