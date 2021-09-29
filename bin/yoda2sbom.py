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

from argparse import RawTextHelpFormatter
import argparse
import glob
import json
import os.path
import os
import subprocess
import sys
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

COMPONENT_DIR = "compliance-results/"

class YodaSBoM:

    def __init__(self, recursive = False, verbose = False):
        self.recursive = recursive
        self.create_packages = {}
        self.package_files = {}
        self.packages = {}
        self.verbose_mode = verbose

    def verbose(self, message):
        if self.verbose_mode:
            print(str(message), file=sys.stderr)
        
    def read_component_file(self, cf):
        self.verbose("Read component file: " + str(cf))
        with open(cf) as fp:
            return json.load(fp)

    def spdx_creation_info(self):
        self.verbose("Create SPDX creation information")
        creation_info = {}
        creation_info['created'] = time.strftime("%Y-%m-%dT%H:%M:%SZ")
        creation_info['creators'] = []
        creation_info['creators'].append("Organization: s")
        creation_info['creators'].append("Person: s")
        return creation_info

    def _spdx_ref(self, top_package, package_name):
        return "SPDXRef-Package-" + top_package + "-" + package_name
    
    def _ext_doc_id(self, top_package, version):
        return "DocumentRef-" + top_package + "-" + version
    
    def _int_doc_id(self, top_package, version):
        return "DocumentRef-" + top_package + "-" + version
    
    def spdx_package(self, top_package, package, homepage, existing_pkg):
        self.verbose("Create SPDX package for: " + top_package + " / " + str(package['file']))
        s_pkg = {}

        if existing_pkg is None:
            package_name = package['subPackage']
            s_pkg['SPDXID'] = self._spdx_ref(top_package, package_name)
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
                license = "unknown"
            s_pkg['licenseDeclared'] = package['license']
            s_pkg['licenseConcluded'] = license
        else:
            #print("reusing: " + str(existing_pkg))
            s_pkg = existing_pkg

        #print("package: " + s_pkg['name'] + " " + str(existing_pkg is None))
        if self.recursive:
            package_spdx_id = s_pkg['SPDXID']
            self.packages[package_spdx_id] = {}
            self.packages[package_spdx_id]['package'] = s_pkg
            self.packages[package_spdx_id]['dependencies'] = []
            
            for dep in package['dependencies']:
                if 'valid' not in package or package['valid'] == True:
                    print(" * dep " + str(dep['package'] + " / " + str(dep['subPackage'] + " / " + str(dep['version'] + " / " ))))
                    component_dir = os.path.join(COMPONENT_DIR, dep['package'])
                    component_version_dir = os.path.join(component_dir, dep['version'])
                    #print (" ---- dir: " + str(component_version_dir))
                    #print(" - look for: " + dep['package'] + "   on behalf of: " + s_pkg['name'])
                    for f in glob.glob(component_version_dir +"*/" + dep['package'] + "-component.json"):
                        top_package = self.spdx_top_package(f)
                        dep_info = {}
                        dep_info['package'] = dep['package']
                        dep_info['sub_package'] = dep['subPackage']
                        dep_info['version'] = dep['version']
                        dep_info['component_file'] = f
                        dep_info['spdx_file'] = self._yoda_to_spdx_name(f)
                        self.packages[package_spdx_id]['dependencies'].append(dep_info)
                        #print(" - add: " + dep['package'] + " to: " + s_pkg['name'], file=sys.stderr)

        return s_pkg

    def _yoda_to_spdx_name(self, package_file):
        return package_file.replace("-component.json", ".spdx.json")
    
    def spdx_top_package(self, package_file):
        self.verbose("Create SPDX package from file: " + package_file)
        print("Create SPDX package from file: " + package_file)

        spdx_file = self._yoda_to_spdx_name(package_file)

        #if os.path.exists(spdx_file):
        #    print("not creating file: " + str(spdx_file), file=sys.stderr)
        #    return

        component = self.read_component_file(package_file)
        top_package = component['package']

        if top_package in self.package_files:
            print("Already done with or doing: " + str(spdx_file), file=sys.stderr)
            return

        self.package_files[top_package] = spdx_file
        
        if top_package in self.create_packages:
            print("already looked (or looking) at: " + top_package, file=sys.stderr)
            return self.create_packages[top_package]
        
        package = {}
        package['SPDXID'] = "SPDXRef-DOCUMENT"
        package['spdxVersion'] = "SPDX-2.2"
        package['creationInfo'] = self.spdx_creation_info()
        version = component['version']
        package['name'] = top_package + "-" + version
        package['dataLicense'] = "CC0-1.0"
        package['documentNamespace'] = top_package + "-" + version + "-" + str(uuid.uuid4())

        homepage = component['homepage']
        package['packages'] = []
        
        for p in component['packageFiles']:
            if 'valid' in p and not p['valid']:
                continue
            _existing_pkg = None
            for _check_pkg in package['packages']:
                if _check_pkg['name'] == p['subPackage']:
                    #print(" --=== WOHA MULE ===---")
                    _existing_pkg = _check_pkg
            if _existing_pkg is None:
                s_pkg = self.spdx_package(top_package, p, homepage, _existing_pkg)
                if s_pkg is not None:
                    package['packages'].append(s_pkg)


        self.create_packages[top_package] = package

        return package


    def add_depenencies(self):
        self.verbose("Add dependencies")
        
        # DEBUG output
        print("\n", file=sys.stderr)
        print("Top packages: ", file=sys.stderr)
        print("---------------------------", file=sys.stderr)
        for k, v in self.create_packages.items():
            print("top: " + k , file=sys.stderr)
            dep_data = {}
            ext_ref_data_list = []
            relationship_list = []
            for p in v['packages']:
                p_spdx_id = p['SPDXID']
                #print("   * p: " + str(p['SPDXID']) + " " + str(p_spdx_id), file=sys.stderr)
                for d in self.packages[p_spdx_id]['dependencies']:
                    d_spdx_id = self._spdx_ref(d['package'], d['sub_package'])
                    d_spdx_file = d['spdx_file']
                    d_ext_doc_id = self._ext_doc_id(d['package'], d['version'])

                    #print("      * d: " + str(d), file=sys.stderr)
                    #print("      * d: " + str(d_spdx_id), file=sys.stderr)
                    #print("      * d: " + str(d_spdx_file), file=sys.stderr)
                    #print("      * d: " + str(d_ext_doc_id), file=sys.stderr)

                    internal_package = (d['package'] == k)

                    if internal_package:
                        pass
                    else:
                        ext_ref_data = {}
                        ext_ref_data['externalDocumentId'] = d_ext_doc_id
                        ext_ref_data['spdxDocument'] = os.path.basename(d_spdx_file)
                        ext_ref_data['checksum'] = {}
                        ext_ref_data['checksum']['algorithm'] = "SHA1"
                        ext_ref_data['checksum']['checksumValue'] = "00000000"
                        ext_ref_data_list.append(ext_ref_data)

                    
                    relationship = {}
                    if internal_package:
                        relationship['spdxElementId'] = self._spdx_ref(d['package'], d['sub_package'] )
                    else:
                        relationship['spdxElementId'] = d_ext_doc_id + ":" + self._spdx_ref(d['package'], d['sub_package'] )
                    relationship['relatedSpdxElement'] = p_spdx_id
                    relationship['relationshipType'] = "DYNAMIC_LINK"
                    
                    
                    # TODO: add checksum
                    relationship_list.append(relationship)
            v['externalDocumentRefs'] = ext_ref_data_list
            v['relationships'] = relationship_list
        print("\n", file=sys.stderr)
        
    def write_package_to_file(self):
        if self.recursive:
            self.add_depenencies()
        
        for key, package in self.create_packages.items():
            spdx_file = self.package_files[key]
            #print("  * " + key , file=sys.stderr)
            #print("     f: " + str(spdx_file), file=sys.stderr)
            #print("     p: " + str(package) , file=sys.stderr)
            
            with open(spdx_file, "w") as outfile:
                print("Creating file: " + spdx_file, file=sys.stderr)
                json.dump(package, outfile, indent=4)


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

    parser.add_argument('-r', '--recursive',
                        action='store_true',
                        dest='recursive',
                        help='analyse package recursively',
                        default=False)

    parser.add_argument('-v', '--verbose',
                        action='store_true',
                        help='output verbose message',
                        default=False)

    args = parser.parse_args()

    return args




def main():

    args = parse()

    yoda_sbom = YodaSBoM(args.recursive, args.verbose)
    
    yoda_sbom.spdx_top_package(args.file)

    yoda_sbom.write_package_to_file()

    

    
if __name__ == '__main__':
    main()
