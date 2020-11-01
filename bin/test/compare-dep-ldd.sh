#!/bin/sh

# SPDX-FileCopyrightText: 2020 Henrik Sandklef
#
# SPDX-License-Identifier: GPL-3.0-or-later

# this scripts verifies that the finding the deps via:
#   readelf
#   ldd
# gives the same result, under the condition that we only collect
# uniq license names and discard the tree structure of the deps


TMP_DIR=/tmp/.vinland/test

EXCLUDE_LIBC_STUFF=" -e ld-linux-x86-64.so.2 -e linux-vdso.so.1 "

# for f in $(apt-file list libc6 | grep "gnu/lib" | cut -d ":" -f 2 ); do echo -n " -e $(basename $f)" ; done | xcpin
EXCLUDE_LIBC_STUFF="$EXCLUDE_LIBC_STUFF -e libBrokenLocale-2.31.so -e libBrokenLocale.so.1 -e libSegFault.so -e libanl-2.31.so -e libanl.so.1 -e libc-2.31.so -e libc.so.6 -e libdl-2.31.so -e libdl.so.2 -e libm-2.31.so -e libm.so.6 -e libmemusage.so -e libmvec-2.31.so -e libmvec.so.1 -e libnsl-2.31.so -e libnsl.so.1 -e libnss_compat-2.31.so -e libnss_compat.so.2 -e libnss_dns-2.31.so -e libnss_dns.so.2 -e libnss_files-2.31.so -e libnss_files.so.2 -e libnss_hesiod-2.31.so -e libnss_hesiod.so.2 -e libnss_nis-2.31.so -e libnss_nis.so.2 -e libnss_nisplus-2.31.so -e libnss_nisplus.so.2 -e libpcprofile.so -e libpthread-2.31.so -e libpthread.so.0 -e libresolv-2.31.so -e libresolv.so.2 -e librt-2.31.so -e librt.so.1 -e libthread_db-1.0.so -e libthread_db.so.1 -e libutil-2.31.so -e libutil.so.1 "


mkdir -p ${TMP_DIR}
check_program()
{
    PROG=$1
    PROG_SHORT=$(basename $PROG)

    printf "%-30s" "$PROG:"

    # dependencies.sh
    ~/opt/vinland/compliance-utils/bin/dependencies.sh -u $PROG \
                                                       > ${TMP_DIR}/${PROG_SHORT}-deps.log
    # ldd
    ldd $(which $PROG)  | \
        awk ' { print $1 }' | \
        grep -v $EXCLUDE_LIBC_STUFF | \
        sort -u \
             > ${TMP_DIR}/${PROG_SHORT}-ldd.log
    RET=$?

    diff ${TMP_DIR}/${PROG_SHORT}-deps.log ${TMP_DIR}/${PROG_SHORT}-ldd.log >/dev/null 2>&1
    RET=$?
    echo "$RET"
    if [ $RET -ne 0 ]
    then
        echo "Found diff between:"
        echo " ${TMP_DIR}/${PROG_SHORT}-deps.log"
        echo " ${TMP_DIR}/${PROG_SHORT}-ldd.log"
        echo
        sdiff -s ${TMP_DIR}/${PROG_SHORT}-deps.log ${TMP_DIR}/${PROG_SHORT}-ldd.log
        exit $RET
    fi
}


#check_program cnee
#check_program ls
#check_program git
#check_program evince
#check_program knock
check_program vim.gtk3
check_program vlc
check_program konqueror


