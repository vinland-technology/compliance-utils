#!/usr/bin/python3

import os.path
import os
import getpass
import datetime
import sys
import glob
from re import search
import re 
import json
import argparse
import subprocess
from enum import Enum
import time
from datetime import date


PROGRAM_NAME="Yoga (Yoda's Generic Analyser)"
PROGRAM_VERSION="0.1"
PROGRAM_URL="https://github.com/vinland-technology/compliance-utils"
PROGRAM_COPYRIGHT="(c) 2020 Henrik Sandklef<hesa@sandklef.com>"
LICENSE="GPL-3.0-or-later"
OUTPUT_LICENSE="public domain"

def error(msg):
    sys.stderr.write(msg + "\n")

def verbose(msg):
    if VERBOSE:
        sys.stderr.write(msg)
        sys.stderr.write("\n")
        sys.stderr.flush()


#
def read_flict_file(package, directory):
    flict_exit_code=None
    flict_file=directory + "/" + package + "-compliance.txt"
    try:
        with open(flict_file) as f:
            flict_exit_code=f.readline().replace("\n","").strip()
    except Exception as e:
        #print("exception: " + str(e))
        pass
    return flict_exit_code

def read_flict_report(package, directory):
    flict_report=directory + "/" + package + "-compliance-report.json"
    try:
        with open(flict_report) as fp:
            return json.load(fp)
    except Exception as e:
        #print("exception: " + str(e))
        pass
    return None
    
def read_package_info(package, directory):
    flict_json = directory + "/" + package + "-component-flict-fixed.json"
    try:
        map={}
        with open(flict_json) as fp:
             json_data=json.load(fp)
             return json_data
    except Exception as e:
        #print("exception: " + str(e))
        pass
    return None

def copyright_and_license_file_present(package, version, directory):
    cop_lic_file=directory + "/" + package + "-" + str(version) + "-lic-cop.zip"
    try:
        with open(cop_lic_file) as fp:
            return cop_lic_file
    except:
        pass
    return False
    

def source_code_file_present(package, version, directory):
    cop_lic_file=directory + "/" + package + "-" + str(version) + "-src.zip"
    try:
        with open(cop_lic_file) as fp:
            return cop_lic_file
    except:
        pass
    return None

def read_from_json(json_data, key):
    if key != None and json_data != None and key in json_data:
        return json_data[key]
    return None

def read_from_json_bool(json_data, key):
    if key != None and json_data != None and key in json_data and json_data[key]:
        return "OK" #json_data[key]
    return "missing"



def license_expression(license_list):
    outer_lic_expr=""
    for lic in license_list:
        lic_expr=""
        for inner_lic in lic:
            if (lic_expr==""):
                lic_expr = inner_lic['spdx']
                #print("lic_ " + lic_expr)
            else:
                lic_expr = lic_expr + " & " + inner_lic['spdx']
        if (outer_lic_expr==""):
            outer_lic_expr = lic_expr
        else:
            outer_lic_expr = outer_lic_expr + " | " + lic_expr
        
    return outer_lic_expr

def outbound_license(package):
    report = package['flictReport']
    #    print("---------------- report? " + str(report))
    policy_types=[ "allowed", "avoid", "denied" ]

    for policy_type in policy_types:
        if report != None and policy_type in report['outbound'] and len(report['outbound'][policy_type]) > 0:
            expr = license_expression(report['outbound'][policy_type])
            #print("expr: " + expr)
            return expr
    return "unknown"

def read_package_dir(package, directory):
    map={}
    map['name']=package
    verbose("    * reading " + directory + "(" + package +")")

    # package information
    package_json=read_package_info(package, directory)
    #print("p: " + str(package_json))
    component=read_from_json(package_json, 'component')
    #print("c: " + str(component))
    ## declared license
    map['declaredLicense']=read_from_json(component, 'license')
    
    version=read_from_json(component, 'version')
    map['version']=version
    #print("v: " + str(map['version']))
    #print("l: " + str(map['declaredLicense']))
    #print("")
    #print("")
    #print("")

    # flict exit code
    map['flictExitCode']=read_flict_file(package, directory)
    # flict compliance report
    map['flictReport']=read_flict_report(package, directory)

    # copyright and license file present
    map['copyrightLicenseFile']=copyright_and_license_file_present(package, version, directory)
    # source code file present
    map['sourceCodeFile']=source_code_file_present(package, version, directory)
    
    return map


def read_yoga_dir(directory):
    dir = directory + "/*"
    packages={}
    verbose("reading " + dir)
    for file in glob.glob(dir):
        if os.path.isdir(file):
            verbose(" * " + file)
            package=file.replace(directory, "").replace("/","")
            map = read_package_dir(package, file)
            packages[package]=map

    return packages

def flict_exit_code_to_str(exit_code):
    #    print("exit_code: " + str(exit_code ))

    if exit_code == None:
        return "unknown"
    
    if exit_code == "0":
        return "OK"
    elif exit_code == "1":
        return "OK (with avoid)"
    elif exit_code == "2":
        return "OK (with denied)"
    else:
        return "unknown"

def write_html_package(package):

    #print("write: " + str(package))
    res =       "    <div class=\"rTableRow\">\n"
    res = res + "      <div class=\"rTableCell\">" + read_from_json(package, 'name') + "</div>\n"
    res = res + "      <div class=\"rTableCell\">" + str(read_from_json(package, 'version')) + "</div>\n"
    res = res + "      <div class=\"rTableCell\">" + str(read_from_json(package, 'license')) + "</div>\n"
    res = res + "      <div class=\"rTableCell\">" + flict_exit_code_to_str(read_from_json(package, 'flictExitCode')) + "</div>\n"
    res = res + "      <div class=\"rTableCell\">" + str(outbound_license(package)) + "</div>\n"
    res = res + "      <div class=\"rTableCell\">" + str(read_from_json_bool(package, 'copyrightLicenseFile')) + "</div>\n"
    res = res + "      <div class=\"rTableCell\">" + str(read_from_json_bool(package, 'sourceCodeFile')) + " </div>\n"
    res = res + "    </div>\n"
    return res
              
def write_html(outdir, packages):
    res = ""
    res = res +  "<html>"
    res = res +  "  <head> "
    res = res +  "    <link rel=\"stylesheet\" href=\"yocto-compliance.css\">"
    res = res +  "  </head>"
    res = res +  "  <body>"
    res = res +  "  <h1>Yocto build compliance</h1>"
    res = res +  "  <h2>Summary</h2>"
    res = res +  "  <h3>${#PACKAGES[@]} packages</h3>"
    res = res +  "  <ul>"
    res = res +  "    <li>${MISSING_FILE} with missing report (unsupported license, only contains script, text, configuration)</li>"    
    res = res +  "  </ul>"
    res = res +  "<h2>Packages</h2>"
    res = res +  "  <div class=\"rTable\">"
    res = res +  "    <div class=\"rTableRow\">"
    res = res +  "      <div class=\"rTableHead\"><strong>Package</strong></div>"
    res = res +  "      <div class=\"rTableHead\"><strong>Version</strong></div>"
    res = res +  "      <div class=\"rTableHead\"><strong>License</strong></div>"
    res = res +  "      <div class=\"rTableHead\"><strong>Compatible</strong></div>"
    res = res +  "      <div class=\"rTableHead\"><strong>Outbound</strong></div>"
    res = res +  "      <div class=\"rTableHead\"><strong>Copyright & License</strong></div>"
    res = res +  "      <div class=\"rTableHead\"><strong>Source code</strong></div>"
    res = res +  "    </div>"
    
    for pkg in packages:
        #print(str(packages[pkg]))
        res = res + write_html_package(packages[pkg])

    res = res +  "  </div>"
    res = res +  "</table>"
    res = res +  "</body></html>"

    return res
              
def write_json(outdir, packages):
    print(json.dumps(packages))
    

def fmt_funs():
    fmt_funs={}
    fmt_funs['json']=write_json
    fmt_funs['html']=write_html
    return fmt_funs

def parse():
    parser = argparse.ArgumentParser(
        description=PROGRAM_NAME,
        epilog=PROGRAM_COPYRIGHT
    )
    parser.add_argument('-v', '--verbose', action='store_true',
                        help='output verbose information to stderr', default=False)
    parser.add_argument('-f', '--format', type=str,
                        help='output result in specified format(s) separated by colon', default="JSON")
    parser.add_argument('-yd', '--yoga-dir', type=str, dest='yoga_dir', 
                        help='directory where Yoda\'s stuff is loated', default="./yoda-output")
    parser.add_argument('-d', '--output-dir', type=str, dest='outdir', 
                        help='directory for reports', default="./yocr-output")

    args = parser.parse_args()
    global VERBOSE
    VERBOSE=args.verbose

    return args

def main():
    args = parse()

    verbose("verbose: " + str(args.verbose))
    verbose("mode:    " + str(args.format))

    packages = read_yoga_dir(args.yoga_dir)

    fmt_functions=fmt_funs()
    
    for fmt in args.format.split(":"):
        print(fmt_functions[fmt.lower()](args.outdir, packages))
        

if __name__ == '__main__':
    START_TIME=datetime.datetime.now()
    main()

