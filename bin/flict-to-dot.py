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


#
# Converts flict package to dot format (for graph generation)
#
import json
import os
import sys
import argparse
from argparse import RawTextHelpFormatter


PROGRAM_NAME="flict-to-dot.py"
PROGRAM_DESCRIPTION="Converts a flict file to dot format"
PROGRAM_VERSION="0.1"
PROGRAM_URL="https://github.com/vinland-technology/compliance-utils"
PROGRAM_COPYRIGHT="(c) 2021 Henrik Sandklef<hesa@sandklef.com>"
PROGRAM_LICENSE="GPL-3.0-or-larer"
PROGRAM_AUTHOR="Henrik Sandklef"
PROGRAM_SEE_ALSO=""

VERBOSE=False

#
# 
#
def package_to_dot(package):
    name = package["name"]
    lic = package["license"]
    dependencies = package["dependencies"]
    dep_lines = set()
    for dep in dependencies:
      if "valid" not in dep or dep['valid']:
          dep_name = dep["name"]
          dep_lic  = dep["license"]
          dep_string = "\"" + name + " (" + lic + ")\" ->" + "\"" + dep_name + " (" + dep_lic + ")\""
          dep_lines.add(dep_string)
          dep_lines.update(package_to_dot(dep))
    return dep_lines

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

    parser.add_argument('file', type=str,
                        help='file to process', default=None)

    parser.add_argument('-v', '--verbose',
                        action='store_true',
                        help='output verbose information to stderr',
                        default=False)

    args = parser.parse_args()

    global VERBOSE
    VERBOSE=args.verbose
    
    return args
    
def error(msg):
    sys.stderr.write(msg + "\n")

def verbose(msg):
    if VERBOSE:
        sys.stderr.write(msg)
        sys.stderr.write("\n")
        sys.stderr.flush()
    

def main():
    args = parse()

    verbose("Opening file: " + str(args.file))
    try:
        with open(args.file) as fp:
            verbose("Loading JSON from file: " + str(fp.name))
            project = json.load(fp)
            # TODO: sync with flict (should be "project")
            if 'component' in project:
                package = project['component']
            else:
                package = project['project']

            if package == None:
                error("Can't find project tag ('component' or 'project')")
                exit(1)

            if "valid" not in package or package['valid']==True:
                deps = package_to_dot(package)
                # print result
                verbose("Begin printing deps")
                print("digraph depends {")
                print("    node [shape=plaintext]")
                for dep in deps:
                    verbose(" * " + str(dep))
                    print("     " +dep)
                print("}")
            else:
                pass
    except FileNotFoundError:
        error("Could not find file: " + str(args.file))
        exit(1)
    except json.decoder.JSONDecodeError            :
        error(str(args.file) + " does not seem to be in JSON format")
        exit(2)

if __name__ == "__main__":
  main()

