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
def package_to_dot(package):
    name = package["name"]
    lic = package["license"]
    dependencies = package["dependencies"]
    dep_lines = set()
    for dep in dependencies:
      dep_name = dep["name"]
      dep_lic  = dep["license"]
      dep_string = "\"" + name + " (" + lic + ")\" ->" + "\"" + dep_name + " (" + dep_lic + ")\""
      dep_lines.add(dep_string)
      dep_lines.update(package_to_dot(dep))
    return dep_lines

def main(inpath):
  with open(inpath) as fp:
    # TODO: sync with flict (should be "package")
    package = json.load(fp)["component"]
    deps = package_to_dot(package)
    # print result
    print("digraph depends {")
    print("    node [shape=plaintext]")
    for dep in deps:
      print("     " +dep)
    print("}")

    
if __name__ == "__main__":
  main(sys.argv[1])

