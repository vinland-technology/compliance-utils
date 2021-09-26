#!/usr/bin/python3

###################################################################
#
# FOSS Compliance Utils / yoda2sbom
#
# SPDX-FileCopyrightText: 2021 Henrik Sandklef
#
# SPDX-License-Identifier: GPL-3.0-or-later
#
###################################################################

#import datetime
from argparse import RawTextHelpFormatter
import argparse
import json
import os.path
import os
import subprocess
import time
import uuid

PROGRAM_NAME="yoda2sbom (Yoda file to SBoM)"
PROGRAM_NAME_SHORT="yoda2sbom.py"
PROGRAM_DESCRIPTION="yoda2sbom.py"
PROGRAM_URL="https://github.com/vinland-technology/compliance-utils"
PROGRAM_COPYRIGHT="(c) 2020 Henrik Sandklef<hesa@sandklef.com>"
PROGRAM_LICENSE="GPL-3.0-or-later"
PROGRAM_AUTHOR="Henrik Sandklef"
PROGRAM_SEE_ALSO=""
PROGRAM_EXAMPLES=""
PROGRAM_EXAMPLES += "  This tool assumes you're located in Yocto's `build` directory.\n"
PROGRAM_EXAMPLES += "  \n\n"

COMPONENT_FILE = "compliance-results/cairo/1.16.0-r0/cairo-component.json"

def read_component_file(cf):
    with open(cf) as fp:
        return json.load(fp)

def spdx_creation_info():
    creation_info = {}
    creation_info['created'] = time.strftime("%Y-%m-%dT%H:%M:%SZ")
    creation_info['creators'] = []
    creation_info['creators'].append("Organization: s")
    creation_info['creators'].append("Person: s")
    return creation_info

def spdx_package(top_package, package, homepage):
    s_pkg = {}

    package_name = package['subPackage']
    s_pkg['SPDXID'] = "SPDXRef-Package-" + top_package + "-" + package_name
    s_pkg['name'] = package_name
    s_pkg['versionInfo'] = package['version']
    s_pkg['homepage'] = homepage
    s_pkg['downloadLocation'] = ""
    s_pkg['copyrightText'] = ""
    s_pkg['filesAnalyzed'] = False
    license = package['license']
    command = "flict simplify \"" + license + "\""
    try:
        res = subprocess.check_output(command, shell=True)
        reply = str(res.decode("utf-8"))
        json_data = json.loads(reply)
        simplified = json_data['simplified']
        license = simplified
        #print("simplified: " + str(simplified))
    except Exception as e:
        COMPLIANCE_UTILS_VERSION="unknown"
    s_pkg['licenseDeclared'] = license
    s_pkg['licenseConcluded'] = license
    
    return s_pkg

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


    parser.add_argument('file', type=str,
                        help='file to create SBoM from', default=None)

    args = parser.parse_args()

    return args
    
    
def main():

    args = parse()
    
    component = read_component_file(args.file)
    
    package = {}
    package['SPDXID'] = "SPDXRef-DOCUMENT"
    package['spdxVersion'] = "SPDX-2.2"
    package['creationInfo'] = spdx_creation_info()
    top_package = component['package']
    version = component['version']
    package['name'] = top_package + "-" + version
    package['dataLicense'] = "CC0-1.0"
    package['documentNamespace'] = top_package + "-" + version + "-" + str(uuid.uuid4())

    
    homepage = component['homepage']
    package['packages'] = []
    for p in component['packageFiles']:
        s_pkg = spdx_package(top_package, p, homepage)
        package['packages'].append(s_pkg)
        
    print(json.dumps(package))
    
if __name__ == '__main__':
    main()
