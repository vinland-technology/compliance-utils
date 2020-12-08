#!/usr/bin/python3

###################################################################
#
# FOSS Compliance Utils / Yoda to flict 
#
# SPDX-FileCopyrightText: 2020 Henrik Sandklef
#
# SPDX-License-Identifier: GPL-3.0-or-later
#
###################################################################

import argparse
from argparse import RawTextHelpFormatter
import json
import os
import sys

PROGRAM_NAME="yoda2flict"
PROGRAM_DESCRIPTION="yoda2flict transforms the output from yoda to a format flict understands"
PROGRAM_VERSION="0.1"
PROGRAM_URL="https://github.com/vinland-technology/compliance-utils"
PROGRAM_COPYRIGHT="(c) 2020 Henrik Sandklef<hesa@sandklef.com>"
PROGRAM_LICENSE="GPL-3.0-or-larer"
PROGRAM_AUTHOR="Henrik Sandklef"
PROGRAM_SEE_ALSO="yoda (Yocto Dependency Analyser)\n  yoga (yoda's generic aggregator)\n  yocr (yoga's compliance reporter)\n  flict (FOSS License Compatibility Tool)"

DEFAULT_DEPENDENCY_FORMAT="pile"
DEFAULT_OUTPUT_DIRECTORY="."
VERBOSE=False

here = "."


def error(msg):
    sys.stderr.write(msg + "\n")

def verbose(msg):
    if VERBOSE:
        sys.stderr.write(msg)
        sys.stderr.write("\n")
        sys.stderr.flush()

def merge_deps(a, b):
  c = a.copy()
  c.update(b)
  return c

def contains_name(deps, name):
  for dep in deps:
    if dep['name']==name:
      print(name + " in " + str(deps))
      return True
  return False

def pile_of_deps(package):
  dep_map={}
  comp={}
  #print("package: " + str(package))
  if "valid" in package and package['valid']==False:
    #print("package: " + str(package)  + " " + str(package['valid']))
    return dep_map
  comp['name']=package['package']
  comp['license']=package['license']
  comp['version']=package['version']
  comp['dependencies']=[]
  dep_map[comp['name']]=comp
  #print("map: " + str(dep_map))
  for dep in package['dependencies']:
    dep_comp = pile_of_deps(dep)
    dep_map=merge_deps(dep_comp, dep_map)
  #print("return: " + str(dep_map))
  return dep_map

def dep_map_to_list(dep_map):
  dep_list=[]
  for key, value in dep_map.items():
    #print("adding : " + (str(value)))
    dep_list.append(value)
  return dep_list

def save_to_file(json_data, dir_name, file_name):
  if not os.path.exists(dir_name):
    os.makedirs(dir_name)
  file_path = dir_name + "/" + file_name
  f = open(file_path, "w")
  f.write(json.dumps(json_data))
  f.close()
  verbose("Created file: " + file_path)

def save_pile_to_file(json_data, outdir, package_name):
    dir_name = outdir + "/" + package_name
    file_name = package_name + "-pile-flict.json"
    save_to_file(json_data, dir_name, file_name)
  
def save_tree_to_file(json_data, outdir, package_name, package_file):
    dir_name = outdir + "/" + package_name
    file_name = package_name + "_" + package_file + "-tree-flict.json"
    save_to_file(json_data, dir_name, file_name)
  
def print_pile(package, outdir):
    packageFiles = package["packageFiles"]
    dep_map={}
    pile = {}
    for file in packageFiles:
      #print("file: " + str(file))
      if "valid" not in file or file['valid']==True:
        #actual = file['package']
        dep_map=merge_deps(pile_of_deps(file), dep_map)
      else:
        pass
    package_map={}
    package_map['name']=package['package']
    package_map['license']=package['license']
    package_map['version']=package['version']
    package_map['dependencies']=dep_map_to_list(dep_map)
    top_map={}
    # TODO: sync with flict (should be "package")
    top_map['component']=package_map
    verbose("Saving to " + outdir + ", " + package['package'])
    save_pile_to_file(top_map, outdir, package['package'])

def dep_tree(package):
    dep_map={}
    dep_map['name']="popopol"+package['package']
    if not "valid" in package or package['valid']:
        dep_map['component']=package['file']
        dep_map['version']=package['version']
        dep_map['license']=package['license']
        #    dep_map['version']=package['version']
        dep_map['valid']=True
        dependencies=[]
        for dep in package['dependencies']:
            dependencies.append(dep_tree(dep))
        dep_map['dependencies']=dependencies
    else:
        dep_map['valid']=False
    return dep_map


def print_tree(package, outdir):
    packageFiles = package["packageFiles"]
    package_name=package['package']
    package_license=package['license']
    package_version=package['version']
    for file in packageFiles:
      if "valid" not in file or file['valid']:
          verbose("file for JSON:::::: " + package['package'] + "/" + package['package'] + "_" + str(file['file']) + ".json")
          package_map={}
          package_map['name']=file['file']
          package_map['package']=package_name
          package_map['subPackage']=file['subPackage']
          package_map['license']=file['license']
          package_map['version']=file['version']
          dependencies=[]
          #actual = file['package']
          #dep_map=merge_deps(pile_of_deps(file), dep_map)
          verbose("dep: " + str(file['file']))
          for dep in file['dependencies']:
              dependencies.append(dep_tree(dep))
          else:
              pass
          package_map['dependencies']=dependencies
          component_map={}
          component_map['component']=package_map
      
          save_tree_to_file(component_map, outdir, package_name, file['file'])

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
    parser.add_argument('input', type=str,
                            help='input file')

    parser.add_argument('-v', '--verbose',
                            action='store_true',
                            help='output verbose information to stderr',
                            default=False)

    parser.add_argument('-of', '--output-format',
                        dest='output_format',
                        help="format of the output ('pile' or 'tree'), defaults is " + DEFAULT_DEPENDENCY_FORMAT,
                        default=DEFAULT_DEPENDENCY_FORMAT)

    parser.add_argument('-od', '--output-directory',
                        dest='output_directory',
                        help="directory where the resulting JSON file(s) will be created, defaults is " + DEFAULT_OUTPUT_DIRECTORY,
                        default=DEFAULT_OUTPUT_DIRECTORY)

    # TODO outpur dir
    
    
    args = parser.parse_args()
    
    global VERBOSE
    VERBOSE=args.verbose

    return args
    
def main():
  args = parse()

  verbose("verbose:   " + str(VERBOSE))
  verbose("input:     " + args.input)
  verbose("format:    " + str(args.output_format))
  verbose("ouput dir: " + str(args.output_directory))
  
  with open(args.input) as fp:
    package = json.load(fp)
    if args.output_format == "pile":
      print_pile(package, args.output_directory)
    else:
      print_tree(package, args.output_directory)

if __name__ == "__main__":
  main()

