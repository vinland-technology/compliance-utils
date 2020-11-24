#!/usr/bin/python3

###################################################################
#
# Yoda to flict 
#
# SPDX-FileCopyrightText: 2020 Henrik Sandklef
#
# SPDX-License-Identifier: GPL-3.0-or-later
#
###################################################################

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

def pile_of_deps(component):
  dep_map={}
  comp={}
  comp['name']=component['package']
  comp['license']=component['license']
  comp['dependencies']=[]
  dep_map[comp['name']]=comp
  #print("map: " + str(dep_map))
  for dep in component['dependencies']:
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

def print_pile(component):
    componentFiles = component["componentFiles"]
    dep_map={}
    pile = {}
    for file in componentFiles:
      if "valid" not in file or file['valid']==True:
        actual = file['component']
        dep_map=merge_deps(pile_of_deps(actual), dep_map)
      else:
        pass
    component_map={}
    component_map['name']=component['package']
    component_map['license']=component['license']
    component_map['dependencies']=dep_map_to_list(dep_map)
    top_map={}
    top_map['component']=component_map
    
    print(json.dumps(top_map))




def main(inpath):
  with open(os.path.join(here, inpath)) as fp:
    component = json.load(fp)
    print_pile(component)

if __name__ == "__main__":
  main(sys.argv[1])

