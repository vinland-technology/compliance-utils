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
import json
import os
import sys

here = "."

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

def print_pile(package):
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
    print(json.dumps(top_map))




def main(inpath):
  with open(os.path.join(here, inpath)) as fp:
    package = json.load(fp)
    print_pile(package)

if __name__ == "__main__":
  main(sys.argv[1])

