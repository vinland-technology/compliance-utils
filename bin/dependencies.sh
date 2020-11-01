#!/bin/bash

# SPDX-FileCopyrightText: 2020 Henrik Sandklef
#
# SPDX-License-Identifier: GPL-3.0-or-later


#
#
# find dependencies recursively for an ELF program/library 
#
#

OUTPUT_DIR=~/.vinland/compliance-utils/elf-deps
FORMAT=txt

# for f in $(apt-file list libc6 | grep "gnu/lib" | cut -d ":" -f 2 ); do echo -n " -e $(basename $f)" ; done | xcpin
EXCLUDE_LIBC_STUFF="$EXCLUDE_LIBC_STUFF -e libBrokenLocale-2.31.so -e libBrokenLocale.so.1 -e libSegFault.so -e libanl-2.31.so -e libanl.so.1 -e libc-2.31.so -e libc.so.6 -e libdl-2.31.so -e libdl.so.2 -e libm-2.31.so -e libm.so.6 -e libmemusage.so -e libmvec-2.31.so -e libmvec.so.1 -e libnsl-2.31.so -e libnsl.so.1 -e libnss_compat-2.31.so -e libnss_compat.so.2 -e libnss_dns-2.31.so -e libnss_dns.so.2 -e libnss_files-2.31.so -e libnss_files.so.2 -e libnss_hesiod-2.31.so -e libnss_hesiod.so.2 -e libnss_nis-2.31.so -e libnss_nis.so.2 -e libnss_nisplus-2.31.so -e libnss_nisplus.so.2 -e libpcprofile.so -e libpthread-2.31.so -e libpthread.so.0 -e libresolv-2.31.so -e libresolv.so.2 -e librt-2.31.so -e librt.so.1 -e libthread_db-1.0.so -e libthread_db.so.1 -e libutil-2.31.so -e libutil.so.1 "

PROG=$(basename $0)

LIST_DEP_MODE=readelf
LIBC=false

declare -A LIB_DEPENDENCIES
export LIB_DEPENDENCIES

declare -A LIB_PATHS
export LIB_PATHS

err()
{
    echo "$*" 1>&2
}

inform()
{
    echo "$*" 1>&2
}

determine_os()
{
    if [ "$(uname  | grep -ic linux)" != "0" ]
    then
        OS=linux
        if [ -f /etc/fedora-release ]
        then
            DIST=fedora
        elif [ -f /etc/fedora-release ]
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
    else
        echo "UNSUPPORTED OS, bash or ... well, something else"
        echo "Your software"
        echo " * OS:    $(uname)"
        echo " * bash:  $0"
        exit 6
    fi

}

list_dep()
{
    if [ "$1" = "" ]
    then
        echo
        return
    fi


    case "$LIST_DEP_MODE" in
        "readelf")
            echo -n "readelf \"$1\": " >> /tmp/readelf.log
            DEPS=$(readelf -d $1 | \
                       grep NEEDED | \
                       grep -v $EXCLUDE_LIBC_STUFF | \
                       cut -d ":" -f 2 | \
                       sed -e 's,\[,,g' -e 's,],,g' -e 's,[ ]*,,g')
            echo "$? " >> /tmp/readelf.log
            ;;
        "objdump")
            DEPS=$(objdump -x $1 | \
                       grep NEEDED | \
                       grep -v $EXCLUDE_LIBC_STUFF | \
                       awk ' { print $2 }' | \
                       sed -e 's,[ ]*,,g')
            ;;
        "ldd")
            DEPS=$(ldd $1 | \
                       awk ' { print $1} '| \
                       grep -v $EXCLUDE_LIBC_STUFF | \
                       sed -e 's,[ ]*,,g')
            ;;
        *)
            echo "Unknown dep tool"
            exit 100
            ;;
    esac
#    inform "DEPS: $DEPS ($LIST_DEP_MODE)"
    echo $DEPS
}

findlib()
{
    LIB=$1
#    err "check path for $1"
    if [[ "$LIB" =~ ^/ ]] || [[ "$LIB" =~ ^./ ]]
    then
#        err " - use as is $1"
        echo $LIB
    else
 #             err " - find $1"
        #        inform "Looking for $LIB in $LIB_DIRS"
        LIB=$(find $LIB_DIRS -name "${LIB}*" -type f  2>/dev/null | head -1)
    fi
#    if [ "$LIB" = "" ]
 #   then
  #      LIB=$(find $LIB_DIRS -name "${LIB}*" -type f  -follow 2>/dev/null | head -1)
    # fi
    echo $LIB
}

list_deps()
{
    local LIB=$1
    local INDENT="$2"

    
    if [ "${LIB_PATHS[$LIB]}" = "" ]
    then  
        LIB_PATHS[$LIB]=$(findlib $LIB)
#        inform "$LIB saved path: ${LIB_PATHS[$LIB]}"
    fi
    local LIB_PATH=${LIB_PATHS[$LIB]}
 #   inform "$LIB : $LIB_PATH"
    

    if [ "${LIB_DEPENDENCIES[$LIB]}" = "" ]
    then
  #      inform "storing $LIB"
        LIB_DEPENDENCIES[$LIB]=$(list_dep $LIB_PATH)
    else
        #     inform "reading $LIB"
        :
    fi
    libs="${LIB_DEPENDENCIES[$LIB]}"

#        for k in "${!LIB_DEPENDENCIES[@]}"
 #   do
  #      echo " -- $k"
   # done

    
    if [ "$FORMAT" = "txt" ]
    then
        if [ "$LONG" = "true" ]
        then
            echo "$INDENT$LIB_PATH"
        else
            echo "$INDENT$LIB"
        fi            
    fi

    for lib in $libs
    do
        if [ "${LIB_PATHS[$lib]}" = "" ]
        then  
            LIB_PATHS[$lib]=$(findlib $lib)
#            inform "$lib saved path: ${LIB_PATHS[$lib]}"
        fi
        local lib_long=${LIB_PATHS[$lib]}
        local libname
        if [ "$LONG" = "true" ]
        then
            lib_name=$lib_long
        else
            lib_name=$lib
        fi
        case "$FORMAT" in
            "txt")
                list_deps "${lib}" "${INDENT}  "
                ;;
            "dot")
                echo "\"$LIB_NAME\" -> \"$lib_name\""
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
    
    if [ "$LONG" = "true" ]
    then
        PROG_NAME=$PROG
    else
        PROG_NAME=$(basename $PROG)
    fi

    if [ "$FORMAT" = "txt" ]
    then
       echo "$INDENT$PROG_NAME"
    fi

    local lib
    for lib in $(list_dep $PROG)
    do
        case "$FORMAT" in
            "txt")
                list_deps "${lib}" "${INDENT}  "
                ;;
            "dot")
                echo "\"$PROG_NAME\" -> \"$lib\""
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
    if [ "$MD" = "true" ]
    then
        HEADER="# "
        HEADER_OUT="\n"
        HEADER2="## "
        CODE_COMMENT=""
        CODE_IN="\`\`\`"
        CODE_OUT="\`\`\`\n\n"
    else
        HEADER=""
        HEADER2="  "
        CODE_IN="   "
        CODE_OUT=""
        CODE_COMMENT="        "
    fi
    echo -e "${HEADER}NAME${HEADER_OUT}"
    echo -e "   $PROG - list dependencies recursively"
    echo
    echo -e "${HEADER}SYNOPSIS"
    echo -e "   ${CODE_IN}$PROG [OPTIONS] FILES${CODE_OUT}"
    echo
    echo -e "${HEADER}DESCRIPTION"
    echo -e "   List dependencies recursively for a given file. The files can be"
    echo -e "   either a program (named with or without path) or a library "
    echo -e "   (nameed with or whothout with path). If the supplied file does"
    echo -e "   not have path we do our best trying to find it using which or"
    echo -e "   (internal function) findllib."
    echo -e
    echo -e "${HEADER}OPTIONS"
    echo -e "${HEADER2}Library related options"
    echo -e "${CODE_IN}-e, --ELF${CODE_OUT}"
    echo -e "use readelf to find dependencies. Default."
    echo
    echo -e "${CODE_IN}--ldd${CODE_OUT}"
    echo -e "${CODE_COMMENT}use ldd to find dependencies. Default is readelf."
    echo
    echo -e "${CODE_IN}--objdump${CODE_OUT}"
    echo -e "${CODE_COMMENT}use objdump to find dependencies. Default is readelf."
    echo
    echo -e "${CODE_IN}--lib-dir DIR${CODE_OUT}"
    echo -e "${CODE_COMMENT}adds DIR to directories to search for libraries. For every use of this option"
    echo -e "${CODE_COMMENT}the directories are added. If no directory is specified the default directories"
    echo -e "${CODE_COMMENT}are: $DEFAULT_LIB_DIRS"
    echo
    echo -e "${HEADER2}Format options"
    echo -e "${CODE_IN}--dot${CODE_OUT}"
    echo -e "${CODE_COMMENT}create dot like file (in output dir). Autmatically adds: \"-s\" and \"-l\" "
    echo
    echo -e "${CODE_IN}--pdf${CODE_OUT}"
    echo -e "${CODE_COMMENT}create pdf file (in output dir). Autmatically adds: \"-s\" and \"-l\" "
    echo
    echo -e "${CODE_IN}--png${CODE_OUT}"
    echo -e "${CODE_COMMENT}create png file (in output dir). Autmatically adds: \"-s\" and \"-l\" "
    echo
    echo -e "${CODE_IN}--svg${CODE_OUT}"
    echo -e "${CODE_COMMENT}create svg file (in output dir). Autmatically adds: \"-s\" and \"-l\" "
    echo
    echo -e "${CODE_IN}--png${CODE_OUT}"
    echo -e "${CODE_COMMENT}create pdf file (in output dir). Autmatically adds: \"-s\" and \"-l\" "
    echo
    echo -e "${HEADER2}Output options"
    echo -e "${CODE_IN}--outdir, -od DIR${CODE_OUT}"
    echo -e "${CODE_COMMENT}output logs to DIR. Default is ~/.vinland/elf-deps"
    echo
    echo -e "${CODE_IN}-av, --auto-view${CODE_OUT}"
    echo -e "${CODE_COMMENT}open (using xdg-open) the first formats produced"
    echo
    echo -e "${CODE_IN}--long${CODE_OUT}"
    echo -e "${CODE_COMMENT}output directory name with path"
    echo
    echo -e "${CODE_IN}-l, --log${CODE_OUT}"
    echo -e "${CODE_COMMENT}store log in outpur dir, as well as print to stdout"
    echo
    echo -e "${CODE_IN}-s, --silent${CODE_OUT}"
    echo -e "${CODE_COMMENT}do not print to stdout"
    echo
    echo -e "${CODE_IN}-u, --uniq${CODE_OUT}"
    echo -e "${CODE_COMMENT}print uniq dependencies in alphabetical order. "
    echo -e "${CODE_COMMENT}Sets txt more and disables everything else."
    echo
    echo -e "${HEADER}SUPPORTED PLATFORMS${HEADER_OUT}"
    echo -e "* Debian and Ubuntu"
    echo -e "* Fedora and RedHat"
    echo
    echo -e "${HEADER}EXAMPLES${HEADER_OUT}"
    echo -e "${CODE_IN}$PROG evince${CODE_OUT}"
    echo -e "${CODE_COMMENT}lists all dependencies for the program evince"
    echo
    echo -e "${CODE_IN}$PROG --pdf libcairo2.so${CODE_OUT}"
    echo -e "${CODE_COMMENT}lists all dependencies for the library libcairo2.so and creates report in pdf format"
    echo
    echo -e "${CODE_IN}$PROG xdpyinfo xvinfo{CODE_OUT}"
    echo -e "${CODE_COMMENT}lists all dependencies xdpyino and xauth."
    echo
    echo -e "${HEADER}EXIT CODES${HEADER_OUT}"
    echo -e "${CODE_IN}0 - success${CODE_OUT}"
    echo -e "${CODE_IN}1 - could not find file${CODE_OUT}"
    echo -e "${CODE_IN}2 - file not in ELF format${CODE_OUT}"
    echo -e "${CODE_IN}3 - silent and no logging not vailed${CODE_OUT}"
    echo -e "${CODE_IN}4 - unknown or unsupported format${CODE_OUT}"
    echo -e "${CODE_IN}6 - unsupported host operating system${CODE_OUT}"
    echo
    echo -e "${HEADER}AUTHOR"
    echo -e "${CODE_COMMENT}Written by Henrik Sandklef"
    echo
    echo -e "${HEADER}REPORTING BUGS"
    echo -e "${CODE_COMMENT}Add an issue at https://github.com/vinland-technology/compliance-utils"
    echo
    echo -e "${HEADER}COPYRIGHT & LICENSE"
    echo -e "${CODE_COMMENT}Copyright 2020 Henrik Sandklef"
    echo -e "${CODE_COMMENT}License GPL-3.0-or-later"
}

setup_libc_excludes_fedora()
{
    :
}

setup_libc_excludes_debian()
{
    which -s apt-file >/dev/null 2>&1
    if [ $? -eq 0 ]
    then
        for f in $(apt-file list libc6 | grep "gnu/lib" | cut -d ":" -f 2 );
        do
            echo -n " -e $(basename $f)" ;
        done 
    else
#        inform "setup_libc_excludes_debian() using apt-file "
        # generated 2020-11-01
        echo " -e libBrokenLocale-2.31.so -e libBrokenLocale.so.1 -e libSegFault.so -e libanl-2.31.so -e libanl.so.1 -e libc-2.31.so -e libc.so.6 -e libdl-2.31.so -e libdl.so.2 -e libm-2.31.so -e libm.so.6 -e libmemusage.so -e libmvec-2.31.so -e libmvec.so.1 -e libnsl-2.31.so -e libnsl.so.1 -e libnss_compat-2.31.so -e libnss_compat.so.2 -e libnss_dns-2.31.so -e libnss_dns.so.2 -e libnss_files-2.31.so -e libnss_files.so.2 -e libnss_hesiod-2.31.so -e libnss_hesiod.so.2 -e libnss_nis-2.31.so -e libnss_nis.so.2 -e libnss_nisplus-2.31.so -e libnss_nisplus.so.2 -e libpcprofile.so -e libpthread-2.31.so -e libpthread.so.0 -e libresolv-2.31.so -e libresolv.so.2 -e librt-2.31.so -e librt.so.1 -e libthread_db-1.0.so -e libthread_db.so.1 -e libutil-2.31.so -e libutil.so.1 "
    fi
}


setup()
{
    # libc
    if [ "$LIBC" = true ]
    then
        EXCLUDE_LIBC_STUFF=" ______dummy______ "
    else
        EXCLUDE_LIBC_STUFF=" -e ld-linux-x86-64.so.2 -e linux-vdso.so.1 "
        if [ "$DIST" = "debian" ] || [ "$DIST" = "ubuntu" ]
        then
            EXCLUDE_LIBC_STUFF="$EXCLUDE_LIBC_STUFF $(setup_libc_excludes_debian)"
        fi
    fi

    if [ "$DIST" = "debian" ] || [ "$DIST" = "ubuntu" ]
    then
        DEFAULT_LIB_DIRS="/usr/lib64 /usr/lib /lib/x86_64-linux-gnu/"
    else
        DEFAULT_LIB_DIRS="/lib /usr/lib64 /usr/lib"
    fi    
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
        list_deps $(basename $FILE) ""
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
        "--libc"| "-lc")
            LIBC=true
            ;;
        "--no-libc"| "-nlc")
            LIBC=false
            ;;
        "--uniq"| "-u")
            UNIQ=true
            LOG=false        
            SILENT=false
            DOT_FORMATS=""
            FORMAT=txt
            ;;
        "--ldd")
            LIST_DEP_MODE=ldd
            ;;
        "--markdown-help")
            MD=true
            usage
            exit
            ;;
        "--objdump")
            LIST_DEP_MODE=objdump
            ;;
        "--auto-view"|"-av")
            AUTO_VIEW=true
            ;;
        "--readelf")
            LIST_DEP_MODE=readelf
            ;;
        "--log"| "-l")
            LOG=true
            ;;
        "--long")
            LONG=true
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
            FILES="$FILES $1"
            ;;
    esac
    shift
done



determine_os

# Determine glibc related libraries
setup

if [ "$LIB_DIRS" = "" ]
then
    LIB_DIRS=$DEFAULT_LIB_DIRS
fi

for FILE in $FILES
do
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
        printf "}\n" >> $DOT_FILE
        inform "Created dot file: $DOT_FILE"
        
        for fmt in $DOT_FORMATS
        do        
            OUT_FILE=${DOT_FILE}.$fmt
            dot -O -T$fmt ${DOT_FILE}
            inform "Created $fmt file: $OUT_FILE"
        done
        if [ "$AUTO_VIEW" = "true" ]
        then
            FMT=$(echo $DOT_FORMATS | awk '{ print $1}')
            xdg-open ${DOT_FILE}.$FMT
        fi
    else
        if [ "$SILENT" = "true" ]
        then
            err "It does not make sense to use silent mode and NOT log"
            exit 3
        else
            if [ "$UNIQ" = "true" ]
            then
                find_dependencies $FILE | sed 's,[ ]*,,g' | tail -n +2 | sort -u
            else
                find_dependencies $FILE
            fi
        fi
    fi
done
