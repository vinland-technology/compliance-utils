#!/usr/bin/python3

###################################################################
#
# FOSS License Compatibility Graph
#
# SPDX-FileCopyrightText: 2020 Henrik Sandklef
#
# SPDX-License-Identifier: GPL-3.0-or-later
#
###################################################################

import json
import os
import sys
import re
from argparse import RawTextHelpFormatter
import argparse

#
#
#
PROGRAM_NAME="spdx-translations.py"
PROGRAM_DESCRIPTION="Translates license ids from non SPDX to SPDX"
PROGRAM_VERSION="0.1"
PROGRAM_URL="https://github.com/vinland-technology/compliance-utils"
PROGRAM_COPYRIGHT="(c) 2020 Henrik Sandklef<hesa@sandklef.com>"
PROGRAM_LICENSE="GPL-3.0-or-larer"
PROGRAM_AUTHOR="Henrik Sandklef"
PROGRAM_SEE_ALSO="yoga (yoda's generic aggregator)\n  yocr (yoga's compliance reporter)\n  flict (FOSS License Compatibility Tool)"

DEFAULT_TRANSLATIONS_FILE="spdx-translations.json"

VERBOSE=False

def error(msg):
    sys.stderr.write(msg + "\n")

def verbose(msg):
    if VERBOSE:
        sys.stderr.write(msg)
        sys.stderr.write("\n")
        sys.stderr.flush()

def parse():

    description = "NAME\n  " + PROGRAM_NAME + "\n\n"
    description = description + "DESCRIPTION\n  " + PROGRAM_DESCRIPTION + "\n\n"
    
    epilog = ""
    epilog = epilog + "AUTHOR\n  " + PROGRAM_AUTHOR + "\n\n"
    epilog = epilog + "REPORTING BUGS\n  File a ticket at " + PROGRAM_URL + "\n\n"
    epilog = epilog + "COPYRIGHT\n  Copyright " + PROGRAM_COPYRIGHT + ".\n  License " + PROGRAM_LICENSE + "\n\n"
    epilog = epilog + "SEE ALSO\n  " + PROGRAM_SEE_ALSO + "\n\n"
    
    parser = argparse.ArgumentParser(
        description=description,
        epilog=epilog,
        formatter_class=RawTextHelpFormatter
    )
    parser.add_argument('-stf', '--spdx-translation-file',
                        type=str,
                        dest='translations_file',
                        help='files with spdx translations, default is ' + DEFAULT_TRANSLATIONS_FILE,
                        default=DEFAULT_TRANSLATIONS_FILE)
    parser.add_argument('-p', '--package-file',
                        type=str,
                        dest='package_file',                        
                        help='file with package definition')
    parser.add_argument('-v', '--verbose',
                            action='store_true',
                        help='output verbose information to stderr',
                        default=False)
    parser.add_argument('-g', '--graph',
                        action='store_true',
                        help='create graph (dot format) over translations',
                        default=False)
    args = parser.parse_args()

    global VERBOSE
    VERBOSE=args.verbose

    return args

#
# 
#
def to_sed(translations):
    first=True
    for trans in translations:
      t_value = trans["value"]
      t_spdx = trans["spdx"]
      if first:
          pipe=""
      else:
          pipe="|"
      if ( t_spdx != "" ):
        print(pipe + " sed -e 's," + t_value + "\\([ |&\\\"]\\)," + t_spdx + "\\1,g' ", end="")
      first=False


      
#
# TODO: update_license needs a rewrite
#       - overly complicated due to Henrik's lack of Pythonian skills
# 
def update_license(translations, license_expr):
    license_list = license_expr.split()
    for i, d in enumerate(translations):
        for x in range(len(license_list)):
            if d['value'] in license_list[x]:
                #print(license_list[x] + " ---> " + str(d['value']) + " ===> " + str(d['spdx']))
                license_list[x]=d['spdx']         
    license_string=""
    for l in license_list:
        license_string = license_string + l + " "
    return license_string

def update_packages(translations, dependencies):
    updates_deps=[]
    for dep in dependencies:
#        print("license: \"" + dep["license"] + "\"")
        license = dep["license"].strip(' ')
        updated_license=update_license(translations, license)
        dep["license"]=updated_license
        dep_deps = dep["dependencies"]
        updates_deps = update_packages(translations, dep_deps)
    return updates_deps

def read_translations(translations_file):
    with open(translations_file) as fp:
        translation_object = json.load(fp)
        translations=translation_object["spdx-translations"]
        return translations

def read_packages_file(jsonfile, translations):
  with open(jsonfile) as fp:
    packages=json.load(fp)
    # TODO: sync with flict (should be "package")
    package = packages["component"]
    deps = package["dependencies"]
    license=package["license"].strip(' ')
    package["license"]=update_license(translations, license)
    update_packages(translations, deps)
    return packages
    
def main():
    
    args = parse()
    translations = read_translations(args.translations_file)

    if (args.package_file != None ):
        packages = read_packages_file(args.package_file, translations)
        print(json.dumps(packages))
    elif (args.graph):
        print("digraph graphname {")
        first = True
        for trans in translations:
            t_value = trans["value"]
            t_spdx = trans["spdx"]
            print("\"" + t_value + "\" -> \"" + t_spdx + "\"")
            if first:
                pipe=""
            else:
                pipe="|"
                if ( t_spdx != "" ):
                    print(pipe + " sed -e 's," + t_value + "\\([ |&\\\"]\\)," + t_spdx + "\\1,g' ", end="")
                first=False
        print("}")
        
        
if __name__ == "__main__":
  main()

