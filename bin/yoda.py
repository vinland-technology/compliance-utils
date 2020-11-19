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

#
#
#
PROGRAM_NAME="Yoda (Yocto Dependencies Analyser)"
PROGRAM_VERSION="0.1"
PROGRAM_URL="https://github.com/vinland-technology/compliance-utils"
PROGRAM_COPYRIGHT="(c) 2020 Henrik Sandklef<hesa@sandklef.com>"
OUTPUT_LICENSE="public domain"

DATE_FMT='%Y-%m-%d'

LOOKUP_LIBS_FOR_BIN=[ "/usr/lib", "/lib", "/usr/lib/*", "/usr/lib/*/*", "/usr/bin", "/bin", "/usr/libexec", "/usr/libexec/*", "usr/lib/*/*/loaders/" ]

class FileType(Enum):
    DIRECTORY=1,
    SOFT_LINK=2,
    HARD_LINK=3,
    SHELL_SCRIPT=4,
    ELF_PROGRAM=5,
    ELF_LIBRARY=6,
    AR_ARCHIVE=7,
    ASCII_TEXT=8,
    UNICODE_TEXT=9,
    ASCII_TEXT_EXECUTABLE=10,
    GIR=11,
    PYTHON_SCRIPT=12
    HTML=12
    

# map for sub-package => package
# e.g libcario => cairo
SUB_PKG_TO_PACKAGE_MAP={}

# map for subpackages and their path
# e.g. cairo-gobject
#  => ./tmp/work/core2-64-poky-linux/cairo/1.16.0-r0/packages-split/cairo-gobject
SUB_PKG_TO_PATH={}
SUB_PKG_PATH_TO_SUB_PKG={}

PKG_FILES={}
LIB_DEPS={}
GLIBC_EXCLUDES=[]
BIN_PATHS={}
PKG_TO_LICENSE={}
MISSING_FILE=10

START_TIME=0
STOP_TIME=0

VERBOSE=False

def error(msg):
    sys.stderr.write(msg + "\n")

def verbose(msg):
    if VERBOSE:
        sys.stderr.write(msg)
        sys.stderr.write("\n")
        sys.stderr.flush()
        
def error_settings():
    sys.stderr.write("MACHINE:       " + MACHINE + "\n")
    sys.stderr.write("IMAGE:         " + IMAGE + "\n")
    sys.stderr.write("MANIFEST:      " + IMG_MF + "\n")
    sys.stderr.write("DATE:          " + DATE + "\n")
    sys.stderr.write("META_TOP_DIR:  " + META_TOP_DIR + "\n")

def lib_to_regexp(lib):
    return lib.replace('+',"\+")

def build_license_cache():
    global PKG_TO_LICENSE
    with open(LICENSE_MANIFEST) as f:
        package=None
        for line in f.readlines():
            if line.startswith("PACKAGE NAME:"):
                package=line.split(":")[1].rstrip().replace(" ","")
            if line.startswith("LICENSE:"):
                p_license=line.split(":")[1].rstrip()
                #verbose("cache license: \"" + p_license + "\" for ---->\"" + package + "\"<----")
                PKG_TO_LICENSE[package]=p_license
    

def build_cache(build_dir, libc):
    dir=build_dir + "/*/*/packages-split/"
    verbose(" build cache for: " + dir + "\n")
    for file in glob.glob(dir+"/**/"):
        #print("file: " + file)
        if search ("/src/", file):
            continue
        if  file.endswith("-lic/"):
            #print("discard: " + file)
            continue
        short_file=str(file).replace(build_dir+"/", "")
        package=short_file.split(os.sep)[0]
        key = os.path.basename(os.path.normpath(file))
#        verbose("package: " + package + " <=== " + key)
        #verbose("store:   " + key + "=>" + package )
        SUB_PKG_TO_PACKAGE_MAP[key]=package
        SUB_PKG_TO_PATH[key]=file
        SUB_PKG_PATH_TO_SUB_PKG[file]=key
        #verbose("store:   " + key + "=>" + file )

    if libc:
        global GLIBC_EXCLUDES
        GLIBC_EXCLUDES=[]
    else:
        setup_glibc_excludes()
        
    verbose("glibc excludes: " + str(GLIBC_EXCLUDES))
    build_license_cache()

    return None

# REPLACED BY CACHE
#def sub_pkg_to_package(build_dir, sub_pkg):
#    dir=build_dir + "/*/*/packages-split/"
#    print(" search in: " + dir)
#    for file in glob.glob(dir+"/**/"+sub_pkg, recursive=True):
#        if search ("/src/", file):
#            continue
#        if file.endswith("packages-split/" + sub_pkg):
#            file_name = os.path.basename(file)
#            return file_name
#
#    return None
    
def sub_package_to_path(build_dir, sub_pkg):
    if sub_pkg in SUB_PKG_TO_PATH:
        return SUB_PKG_TO_PATH[sub_pkg]
    dir=build_dir + "/*/*/packages-split/"
    sub_pkg_reg_exp=lib_to_regexp(sub_pkg)
    for file_path in glob.glob(dir + sub_pkg_reg_exp, recursive=True):
        if search ("/src/", file_path):
            continue
        #verbose("search: \"" + sub_pkg_reg_exp +"$\"" +  "\"" + file_path + "\"\n")
        if search(sub_pkg_reg_exp+"$", file_path):
            if search("packages-split/*" + sub_pkg_reg_exp + "[ ]*$", file_path):
                SUB_PKG_TO_PATH[sub_pkg]=file_path
                return file_path
    return None



def artefact_to_sub_package(build_dir, artefact):
#    print("arty: " + artefact)
    file=build_dir + "/*/*/*/runtime-reverse/" + artefact
    for file_path in glob.glob(file, recursive=True):
        if os.path.islink(file_path):
            followed_link = os.readlink(file_path)
            sub_package = os.path.basename(followed_link)
            return sub_package
        


def image_artefacts(image_file):
    artefacts=[]
    if not os.path.isfile(image_file):
        error ("File \"" + image_file + "\" does not exist")
        error_settings()
        exit(MISSING_FILE)
    with open(image_file) as f:
        for line in f.readlines():
            cols = line.split()
            artefact = cols[0]
            if not artefact.endswith("-lic"):
                artefacts.append(artefact)
    return artefacts            

def program_info():
    return {
        'name': PROGRAM_NAME,
        'version': PROGRAM_VERSION,
        'url': PROGRAM_URL,
        'copyright': PROGRAM_COPYRIGHT,
        'result-license': OUTPUT_LICENSE
    }

def producer_info():
    producer_map={}
    yocto_map= {
        'machine': MACHINE,
        'distDir': DIST_DIR,
        'image': IMAGE,
        'imageManifest': IMG_MF,
        'buildDir': BUILD_DIR,
        'metaTopDir': META_TOP_DIR,
    }
    date_map = {
        'date': date.today().strftime(DATE_FMT)
    }
    producer_map['tool']=program_info()
    producer_map['yocto']=yocto_map
    producer_map['date']=date_map
    return producer_map

def flict_info():
    return {
        "software":"flict",
        "version":"0.1"
    }

def host_info():
    uname=os.uname()
    return {
        'os': uname.sysname,
        'osRelease': uname.release,
        'osVersion': uname.version,
        'machine': uname.machine,
        'host': uname.nodename,
        'user': getpass.getuser()
    }

def file_type(file):
    # sneaky way, check suffix
    if file.endswith(".html"):
        return FileType.HTML
    
    command = "/usr/bin/file \"" + file +"\""
    res = subprocess.check_output(command, shell=True)
    result = str(res.decode("utf-8")).replace(file+":", "")

    #verbose("result: " + result)
    if "LSB shared object" in result:
        #verbose("LSB for " + file)
        if "interpreter" in result:
            if ".so" in file:
                # this is typically glibc stuff
                #verbose("LSB for " + file  + " is lib")
                return FileType.ELF_LIBRARY
            else:
                #verbose("LSB for " + file  + " is program")
                return FileType.ELF_PROGRAM
        else:
            #verbose("LSB for " + file  + " is lib")
            return FileType.ELF_LIBRARY
    elif "directory" in result:
        return FileType.DIRECTORY

#
# if a bin (e.g. libpthread.so.0) is NOT a file we need to fall back
# to checking the link and from that get the file name
#
def find_bin_link_worker_helper(bin_name, search_dir):
    FILES=[]
    #verbose("searching for link in: " + BUILD_DIR + "/*/*/packages-split/*" + search_dir + "/" + bin_name + "*")
    for f in glob.glob(BUILD_DIR + "/*/*/packages-split/*" + search_dir + "/" + bin_name + "*" , recursive=True):
        #verbose("  found: " + f)
        if os.path.islink(f):
            dirname=os.path.dirname(f)
            #verbose("    found: " + f + " is link")
            #verbose("    found: " + f + " has dir " + dirname)
            #verbose("    reading link")
            bin_file=os.path.join(dirname, os.readlink(f))
            #verbose("    found: " + bin_file + " aint't that kinda sweet")
            #verbose("    reading type of " + bin_file)
            ftype = file_type(bin_file)
            #verbose("    type: " + str(ftype))
            if ftype == FileType.ELF_LIBRARY or ftype == FileType.ELF_PROGRAM: 
                FILES.append(bin_file)
            else:
                pass
    return FILES

def find_bin_file_worker_helper(bin_name, search_dir):
    FILES=[]
    #verbose("searching for file in: " + BUILD_DIR + "/*/*/packages-split/*" + search_dir + "/" + bin_name)
    for f in glob.glob(BUILD_DIR + "/*/*/packages-split/*" + search_dir + "/" + bin_name + "*" , recursive=True):
        #print("f: " +str(f))
        if os.path.isfile(f) and not os.path.islink(f) and not ".debug" in f:
            ftype = file_type(f)
            #print("f: " + str(f) + " " + str(ftype))
            if ftype == FileType.ELF_LIBRARY or ftype == FileType.ELF_PROGRAM: 
                FILES.append(f)
            else:
                pass
    return FILES


def find_bin_file_worker(bin_name):
    for dir in LOOKUP_LIBS_FOR_BIN:
        try:
            bin_path = find_bin_file_worker_helper(bin_name, dir)
            if bin_path != None and len(bin_path)!=0:
                return bin_path
        except:
            pass
        try:
            bin_path = find_bin_link_worker_helper(bin_name, dir)
            if bin_path != None and len(bin_path)!=0:
                return bin_path
        except Exception as e:
            verbose(e)
            pass
    verbose("Can not find the path for the binary (link of file): " + bin_name)
    return None

def find_bin_file(bin_name):
    # first, check cache
    if not bin_name in BIN_PATHS:
        bin_paths = find_bin_file_worker(bin_name)
        if bin_paths == None:
            error("No bin paths found for: " + bin_name)
            return None
        if len(bin_paths)!=1:
            error("Not OK size of bin paths (" + str(len(bin_paths)) + ") found for: " + bin_name + ". List: " + str(bin_paths))
            return None
        BIN_PATHS[bin_name]=bin_paths[0]
    else:
        #print("Cached file: " + lib_name)
        pass
    
    return BIN_PATHS[bin_name]

    
def dependencies(elf_file):
    if elf_file not in BIN_PATHS:
        #print("dependencies")
        DEPS=[]
        command = "LD_LIBRARY_PATH=/tmp /usr/bin/readelf -d " + elf_file
        res = subprocess.check_output(command, shell=True)
        result = res.decode("utf-8")
        for line in result.split("\n"):
            if "NEEDED" in line:
                dep_pre = line.split(":")[1]
                dep=dep_pre.replace(" ","").replace("[","").replace("]","")
                #print("cehck dep " + dep)
                #print("check dep " + dep + ": ", end="")
                if len(GLIBC_EXCLUDES) > 0 and dep in GLIBC_EXCLUDES:
                    #print(" PASS (" + str(GLIBC_EXCLUDES) + ")")
                    pass

                else:
                    #print(" USE")
                    #print("KEEP Usin " + dep)
                    #print ("deps: " + dep)
                    DEPS.append(dep)
        BIN_PATHS[elf_file]=DEPS
    return BIN_PATHS[elf_file]

def setup_glibc_excludes():
    global GLIBC_EXCLUDES
    #print("GLIBC GLIBC")
    for f in glob.glob(BUILD_DIR+"/glibc/*/image/lib/**", recursive=True):
        lib=os.path.basename(f)
        if ".so" in lib:
            GLIBC_EXCLUDES.append(lib)
            
def license_for_pkg(pkg_file, bin_file):
    global PKG_TO_LICENSE
    #verbose("license_for_pkg(" + pkg_file + ", " + bin_file + ")")
    #verbose(" * manifest: " + LICENSE_MANIFEST)
    # Try getting from cache
    path=""
    paths=bin_file.replace(BUILD_DIR,"").split("/")
    if len(paths) >= 5:
        path=paths[4]
        if path in PKG_TO_LICENSE:
            lic=PKG_TO_LICENSE[path]
            #verbose(" * cached license:     " + lic + " for " + path)
            return lic

    # Try getting from bb file
    pkg=paths[1]
    verbose(" * lic:     None")
    verbose(" * pkg:     " + pkg)
    verbose(" * mtd:     " + META_TOP_DIR)
    dir=META_TOP_DIR+"/meta*/*/*/"
    verbose(" * dir:     " + dir)
    for bbfile in glob.glob(dir+pkg+"*.bb", recursive=True):
        verbose("bbfile: " + str(bbfile))
        with open(bbfile) as f:
            pn_license=None
            licensel=None
            for line in f.readlines():
                if "LICENSE_${PN}" in line:
                    if "file:" in line: 
                        pass
                    else:
                        pn_license=line.split("=")[1].rstrip().replace("\"","")
                if "LICENSE" in line:
                    if "file:" in line: 
                        pass
                    else:
                        license=line.split("=")[1].rstrip().replace("\"","")
            if pn_license != None:
                PKG_TO_LICENSE[path]=pn_license                
                return pn_license
            if license != None:
                PKG_TO_LICENSE[path]=license                
                return license
    return "UNKNOWN"
            
def package_file_to_component(pkg_file, indent):
    #verbose(indent + pkg_file + " <----------------")
    bin_file=find_bin_file(pkg_file)
    if bin_file == None:
        return failed_component(pkg_file, "Failed to find binary file for " + pkg_file)
    
    deps=dependencies(bin_file)
    deps_deps=[]
    for dep in deps:
        dep_component = package_file_to_component(dep, indent+"  ")
        deps_deps.append(dep_component)
    component={}
    component['name']=pkg_file
    component['license']=license_for_pkg(pkg_file, bin_file)
    component['dependencies']=deps_deps
    return component

def short_name_for_sub_pkg_path(sub_pkg_path):
    if not sub_pkg_path in SUB_PKG_PATH_TO_SUB_PKG:
        SUB_PKG_PATH_TO_SUB_PKG[sub_pkg_path]=str(os.path.basename(sub_pkg_path.rstrip('/')))
    return SUB_PKG_PATH_TO_SUB_PKG[sub_pkg_path]
    
def path_for_sub_pkg(sub_pkg):
    if not sub_pkg in SUB_PKG_TO_PATH:
        SUB_PKG_TO_PATH[sub_pkg]=str(os.path.basename(sub_pkg_path.rstrip('/')))
    return SUB_PKG_TO_PATH[sub_pkg]
    
def files_for_sub_pkg(sub_pkg_short):
    sub_pkg_path=path_for_sub_pkg(sub_pkg_short)
    if not sub_pkg_short in PKG_FILES:
        # TODO: add excludes
        FILES=[]
        
        #verbose("Looking recursively in: " + sub_pkg_path)
        for f in glob.glob(sub_pkg_path+"/**", recursive=True):
            #print(" * : " + f)
            if os.path.isfile(f) and not os.path.islink(f):
                #verbose("   * store: " + f + "\n")
                FILES.append(f)
            #else:
            #    print("   * throw away")
        PKG_FILES[sub_pkg_short]=FILES
    return PKG_FILES[sub_pkg_short]

def component_to_map(component):
    component_map = {}
    component_map['producer']=producer_info()
    component_map['flict-meta']=flict_info()
    component_map['valid']=True
    component_map['component']=component
    return component_map

def failed_components(sub_pkg, msg):
    component={}
    if msg == None:
        msg=""
    component['valid']=False
    component['cause']=msg
    return component

def failed_component(name, msg):
    component={}
    component['name']=name
    component['valid']=False
    if msg == None:
        msg=""
    component['cause']=msg
    return component


def failed_package_to_component(package, msg):
    component={}
    if msg == None:
        msg=""
    component['name']=package
    component['license']="unknown"
    component['depencencies']="unknown"
    component['valid']=False
    component['cause']=msg
    return component

def sub_package_to_component_helper(sub_pkg):
    # e.g
    # package=cairo
    # sub_pkg=cairo-gobject
    #verbose("artefact_to_component_helper " + str(sub_pkg))

    sub_pkg_path = sub_package_to_path(BUILD_DIR, sub_pkg)
    if sub_pkg_path is None:
        error("Failed to find sub-package-path for: " + sub_pkg)
        components=[]
        components.append(failed_package_to_component(sub_pkg, None))
        return components

    # Get short name of lib (possibly cached)
    #sub_pkg_short=short_name_for_sub_pkg_path(sub_pkg_path)
    #verbose("sub_pkg_short: " + sub_pkg_short)
    
    # Get files for sub_pkg
    sub_pkg_files=files_for_sub_pkg(sub_pkg)
    
    files=[]
    components=[]
    for f in sub_pkg_files:
        ftype = file_type(f)
        if ftype == FileType.ELF_PROGRAM or ftype == FileType.ELF_LIBRARY:
            #verbose("  package_file_to_component: " + str(ftype))
            try:
                component = package_file_to_component(os.path.basename(f), "  ")
                component_map = component_to_map(component)
                #verbose("helper: " + str(component_map))
                components.append(component_map)
            except Exception as e:
                component = failed_package_to_component(os.path.basename(f), "failed producing component.")
                components.append(component)
                error("Failed building component structure for: " + str(f))
                error(e)
        else:
            verbose("Ignoring file since not a lib or program: " + str(f))
            component = failed_package_to_component(os.path.basename(f), "Ignoring file since not a lib or program: " + str(f))
            components.append(component)
            #verbose("ignore component: " + str(component))

    return components


def package_to_component(package, sub_pkg):
    # e.g
    # package=cairo
    # sub_pkg=cairo-gobject (None)

#    print("sub_pkg: " + str(sub_pkg))
    sub_pkgs=[]
    if sub_pkg != None:
        sub_pkgs.append(sub_pkg)
    else:
        dir=BUILD_DIR + "/" + package + "/*/packages-split/*"
        for f in glob.glob(dir, recursive=False):
            if "shlibdeps" in f or package+"-staticdev" in f or package+"-dev" in f or package+"-dbg" in f or package+"-lic" in f or package+"-src" in f:
                pass
            else:
                sub_pkgs.append(os.path.basename(f))
                
    components_map={}
    components=[]
    for sp in sub_pkgs:
        try:
            components.extend(sub_package_to_component_helper(sp))
        except Exception as e:
            error("Could not create component from: " + str(sp))
            error(e)
    components_map['components']=components
    return components_map

def artefact_to_component(artefact):
    sub_pkg = artefact_to_sub_package(BUILD_DIR, artefact)
    if sub_pkg == None:
        error("Failed to find sub-package for: " + artefact)
        return None

    components_map={}
    components_map['components']=sub_package_to_component_helper(sub_pkg)
    return components_map
    

def print_artefacts_as_txt(artefacts):
    for key in artefacts:
        if key=='artefacts':
            continue
        print()
        print(str(key))
        print("---------------------------")
        items={}
        items = artefacts[key]
        for subkey in items:
            print("  " + str(subkey) + "=\"" + str(items[subkey])+"\"")
    print()
    print("artefacts")
    print("===========================")
    for artefact in artefacts['artefacts']:
        if 'valid' not in artefact or artefact['valid']=="true":
            print()
            print("  " + str(artefact['name']))
            print("  ---------------------------")
            print("    package:           \"" + str(artefact['package']) + "\"")
            print("    version:           \"" + str(artefact['packageVersion']) + "\"")
            print("    version dir:       \"" + str(artefact['packageVersionDir']) + "\"")
            print("    sub package:       \"" + str(artefact['subPackage']) + "\"")
            print("    sub package path:  \"" + str(artefact['subPackagePath']) + "\"")
        else:
            print()
            print("  " + str(artefact['name']))
            print("  ---------------------------")
            print("    invalid:            " + str(artefact['cause']))

    
def image_to_artefacts(image_file):
    artefacts_map = {}
    artefacts_map['artefacts']=[]
    artefacts_map['meta']=program_info()
    artefacts_map['producer-info']=producer_info()
    
    artefacts = image_artefacts(image_file)
    for artefact in artefacts:
        #verbose(".")
        sub_pkg = artefact_to_sub_package(BUILD_DIR, artefact)
        if sub_pkg == None:
            error("Failed to find sub-package for: " + artefact)
            artefacts_map['artefacts'].append({
                'name': artefact,
                'valid': "false",
                'cause': "Can't find sub-package for artefect " + artefact
            })
            continue
        sub_pkg_path = sub_package_to_path(BUILD_DIR, sub_pkg)
        #        package = sub_pkg_to_package(BUILD_DIR, sub_pkg)
        if sub_pkg_path is None:
            error("Failed to find sub-package-path for: " + artefact + " " + sub_pkg)
            continue
        if sub_pkg in SUB_PKG_TO_PACKAGE_MAP:
            package = SUB_PKG_TO_PACKAGE_MAP[sub_pkg]
            package_version_dir=str(sub_pkg_path).replace(BUILD_DIR, "").replace("packages-split/" + sub_pkg, "").replace(package,"").replace("/","")
            package_version=re.sub(r"-r[0-9]","",package_version_dir)
            #verbose("package_version: " + package_version_dir + "  ===>  " + package_version + "\n")
            #verbose("arg 1: " + BUILD_DIR + "\n")
            #verbose("arg 2: " + sub_pkg + "\n")
            artefacts_map['artefacts'].append({
                'name': artefact,
                'package': package,
                'valid': "true",
                'packageVersion': package_version,
                'packageVersionDir': package_version_dir,
                'subPackage': sub_pkg,
                'subPackagePath': sub_pkg_path
            })

    return artefacts_map

def parse():
    parser = argparse.ArgumentParser(
        description=PROGRAM_NAME,
        epilog=PROGRAM_COPYRIGHT
    )
    parser.add_argument('mode', type=str,
                        help='list or nada', default='list')
    parser.add_argument('-v', '--verbose', action='store_true',
                        help='output verbose information to stderr', default=False)
    parser.add_argument('-f', '--format', type=str,
                        help='output result in specified format', default="JSON")
    parser.add_argument('-lf', '--list-formats', action='store_true', dest='listformats',
                        help='output result in specified format', default=False)
    parser.add_argument('-m', '--machine', type=str,
                        help='machine of Yocto build', default="qemux86-64")
    parser.add_argument('-dd', '--dist-dir', dest='distdir', type=str,
                        help='distribution directory', default="core2-64-poky-linux")
    parser.add_argument('-i', '--image', type=str,
                        help='image', default="core-image-minimal-qemux86-64")
    parser.add_argument('-d', '--date', type=str,
                        help='date of build', default="20201024110850")
    parser.add_argument('-bd', '--build-dir', type=str,
                        help='date of build', default="20201024110850")
    parser.add_argument('-mtd', '--meta-top-dir', type=str, dest='meta_top_dir',
                        help='directory containing for meta directories', default="../")
    parser.add_argument('-a', '--artefact', type=str, dest='managed_artefact',
                        help='artefact to handle')
    parser.add_argument('-aa', '--artefacts-packages', action='store_true', dest='artefact_packages',
                        help='handle all packages as found via artefact list')
    parser.add_argument('-p', '--package', type=str, dest='managed_package',
                        help='packge to handle')
    parser.add_argument('-sp', '--sub-package', type=str, dest='managed_sub_package',
                        help='sub package (requires package) to handle')
    parser.add_argument('-c', '--libc', dest='includelibc', action='store_true',
                        help="include glibc libraries as dependencies", default=False)

    args = parser.parse_args()

    global VERBOSE
    VERBOSE=args.verbose

    if args.listformats:
        print("Supported output formats: JSON and txt")
        exit(11)

    global DIST_DIR
    DIST_DIR=str(args.distdir)

    global MACHINE
    MACHINE=str(args.machine)

    global IMAGE
    IMAGE=str(args.image)

    global IMG_MF
    IMG_MF="tmp/deploy/images/" + MACHINE + "/" + IMAGE + ".manifest"

    global BUILD_DIR
    BUILD_DIR="./tmp/work/" + DIST_DIR

    global META_TOP_DIR
    META_TOP_DIR=str(args.meta_top_dir)
    
    global DATE
    DATE=str(args.date)
    
    global LICENSE_MANIFEST
    LICENSE_MANIFEST="tmp/deploy/licenses/" + IMAGE + "-" + DATE + "/license.manifest"

    return args
    
def main():
    args = parse()
    build_cache(BUILD_DIR, args.includelibc)

    verbose("verbose: " + str(args.verbose) + "\n")
    verbose("mode:    " + str(args.mode) + "\n")
    if args.mode=="list":
        verbose("format: " + str(args.format) + "\n")
        map = image_to_artefacts(IMG_MF)
        if args.format=='JSON':
            print(json.dumps(map))
        elif args.format=='txt':
            print_artefacts_as_txt(map)
    elif args.mode=="component":
        if args.artefact_packages:
            verbose("Getting list of artefacts")
            map = image_to_artefacts(IMG_MF)
            verbose("Looping over the list of artefacts")
            artefacts = map['artefacts']
            artefacts_list=[]
            for artefact in artefacts:
                verbose("Handling artefact: " + str(artefact['name']))
                artefact_map={}
                artefact_map['name']=artefact
                if 'valid' not in artefact or artefact['valid']=="true":
                    package=artefact['package']
                    sub_package=artefact['subPackage']
                    components_map=package_to_component(package, sub_package)
                    artefact_map['components']=components_map['components']
                else:
                    artefact_map['components']={}
                    #print("---leave  " + str(artefact['name']))
                artefacts_list.append([artefact_map])
                continue
            artefacts_map={}
            artefacts_map['meta']=program_info()
            artefacts_map['producer-info']=producer_info()
            artefacts_map['artefacts']=artefacts_list
            
            print(json.dumps(artefacts_map))
        elif args.managed_package != None:
            if args.format=='JSON':
                components_map=package_to_component(args.managed_package, args.managed_sub_package)
                print(json.dumps(components_map))

        else:
            if args.format=='JSON':
                components_map=artefact_to_component(args.managed_artefact)
                print(json.dumps(components_map))
    else:
        error("Missing or incorrect mode")
        exit(110)
        
if __name__ == '__main__':
    START_TIME=datetime.datetime.now()
    main()
