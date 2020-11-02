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

#
# 
#
def component_to_dot(component):
    name = component["name"]
    dependencies = component["dependencies"]
    dep_lines = set()
    for dep in dependencies:
      dep_name = dep["name"]
      dep_string = "\"" + name + "\" ->" + "\"" + dep_name + "\""
      dep_lines.add(dep_string)
      dep_lines.update(component_to_dot(dep))
    return dep_lines

def main(inpath):
  with open(inpath) as fp:
    component = json.load(fp)["component"]
    deps = component_to_dot(component)
    # print result
    print("digraph depends {")
    print("    node [shape=plaintext]")
    for dep in deps:
      print("     " +dep)
    print("}")

    
if __name__ == "__main__":
  main(sys.argv[1])

