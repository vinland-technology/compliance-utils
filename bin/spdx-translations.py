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

def update_components(translations, dependencies):
    updates_deps=[]
    for dep in dependencies:
#        print("license: \"" + dep["license"] + "\"")
        license = dep["license"].strip(' ')
        updated_license=update_license(translations, license)
        dep["license"]=updated_license
        dep_deps = dep["dependencies"]
        updates_deps = update_components(translations, dep_deps)
    return updates_deps

def main(inpath, jsonfile):
  with open(inpath) as fp:
    translation_object = json.load(fp)
    translations=translation_object["spdx-translations"]
#    to_sed(translations)
 #   exit(0)
  #  print("apa")
   # print("apa" + str(type (translations)))
    #    to_sed(translations)
  with open(jsonfile) as fp:
    components=json.load(fp)
    component = components["component"]
    deps = component["dependencies"]
    license=component["license"].strip(' ')
    component["license"]=update_license(translations, license)
    update_components(translations, deps)
    print(json.dumps(components))
    
if __name__ == "__main__":
  main(sys.argv[1], sys.argv[2])

