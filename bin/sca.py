#!/usr/bin/python3

###################################################################
#
# FOSS Compliance Utils / Scancode Analyser
#
# SPDX-FileCopyrightText: 2021 Henrik Sandklef
#
# SPDX-License-Identifier: GPL-3.0-or-later
#
###################################################################

from argparse import RawTextHelpFormatter
import argparse
import glob
import json
import os.path
import os
import re
import subprocess
import sys
import time
import uuid

PROGRAM_NAME="sca (Scancode report file analyser)"
PROGRAM_NAME_SHORT="sca.py"
PROGRAM_DESCRIPTION="Reads a Scancode report and extracts information from selected files"
PROGRAM_URL="https://github.com/vinland-technology/compliance-utils"
PROGRAM_COPYRIGHT="(c) 2021 Henrik Sandklef<hesa@sandklef.com>"
PROGRAM_LICENSE="GPL-3.0-or-later"
PROGRAM_AUTHOR="Henrik Sandklef"
PROGRAM_SEE_ALSO=""
PROGRAM_EXAMPLES=""


def parse():

    description = "NAME\n  " + PROGRAM_NAME + "\n\n"
    description = description + "DESCRIPTION\n  " + PROGRAM_DESCRIPTION + "\n\n"
    
    epilog = ""
    epilog = epilog + "EXAMPLES\n\n" + PROGRAM_EXAMPLES + "\n\n"
    epilog = epilog + "AUTHOR\n  " + PROGRAM_AUTHOR + "\n\n"
    epilog = epilog + "REPORTING BUGS\n  File a ticket at " + PROGRAM_URL + "\n\n"
    epilog = epilog + "COPYRIGHT\n  Copyright " + PROGRAM_COPYRIGHT + ".\n  License " + PROGRAM_LICENSE + "\n\n"
    epilog = epilog + "SEE ALSO\n  " + PROGRAM_SEE_ALSO + "\n\n"
    
    parser = argparse.ArgumentParser(
        description=description,
        epilog=epilog,
        formatter_class=RawTextHelpFormatter
    )


    parser.add_argument('report',
                            type=str,
                            help='Scancode report to analyse',
                            default=None)

    parser.add_argument('-l', '--license',
                        dest='license',
                        help='license expression to match',
                        default=False)

    parser.add_argument('-f', '--file',
                        dest='file',
                        help='file expression to match',
                        default=False)

    parser.add_argument('-v', '--verbose',
                            action='store_true',
                            help='output verbose message',
                            default=None)

    parser.add_argument('-c', '--copyright',
                            dest='copyright',
                            action='store_true',
                            help='add copyright to output',
                            default=None)

    parser.add_argument('-m', '--match',
                            action='store_true',
                            help='add matching license text to output',
                            default=None)

    args = parser.parse_args()

    return args


def print_file(args, f):
    res = f['path'] + " [" + str(f['license_expressions']) + "]"

    if (args.copyright):
        res += "\n"
        if 'copyrights' in f:
            for c in f['copyrights']:
                res += " + " + str(c['value'])
        #res += " " + 

    if (args.match):
        res += "\n"
        for l in f['licenses']:
            res += " + " + str(l['key']) + ": " + str(l['matched_text'])
        #res += " " + 
    print(res)
    
def main():

    args = parse()

    print("report:    " + str(args.report))
    print("license:   " + str(args.license))
    print("file:      " + str(args.file))
    print("verbose:   " + str(args.verbose))
    print("match:     " + str(args.match))
    print("copyright: " + str(args.copyright))

    with open(args.report) as fp:
        json_data = json.load(fp)
        files = json_data['files']

    for f in files:
        path = f['path']
        #print("* " + path + "  " + args.file)
        if re.search(args.file, path):
            print_file(args, f)
        
if __name__ == '__main__':
    main()
