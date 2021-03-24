#!/usr/bin/python3

from argparse import RawTextHelpFormatter
import argparse

import json
import os
import sys

PROGRAM_NAME = "scancode-analyser.py"
PROGRAM_DESCRIPTION = " bla bla "
AUTHOR = "Henrik Sandklef"

UNKNOWN_LICENSE = "unknown"

def parse():

    description = "NAME\n  " + PROGRAM_NAME + "\n\n"
    description = description + "DESCRIPTION\n  " + PROGRAM_DESCRIPTION + "\n\n"
    
    epilog = ""
    #epilog = epilog + "AUTHOR\n  " + PROGRAM_AUTHOR + "\n\n"
    #epilog = epilog + "PROJECT SITE\n  " + PROGRAM_URL + "\n\n"
    #epilog = epilog + "REPORTING BUGS\n  File a ticket at " + BUG_URL + "\n\n"
    #epilog = epilog + "COPYRIGHT\n  Copyright " + PROGRAM_COPYRIGHT + ".\n  License " + PROGRAM_LICENSE + "\n\n"
    #epilog = epilog + "SEE ALSO\n  " + PROGRAM_SEE_ALSO + "\n\n"
    
    parser = argparse.ArgumentParser(
        description=description,
        epilog=epilog,
        formatter_class=RawTextHelpFormatter
    )

    parser.add_argument('file',
                        type=str,
                        help='scancode report file')

    parser.add_argument('-v', '--verbose',
                        action='store_true',
                        help='output verbose information to stderr',
                        default=False)
    
    parser.add_argument('-d', '--directory',
                        dest='dir',
                        help='',
                        default=False)

    parser.add_argument('-tl', '--top-level',
                        dest='top_level',
                        action='store_true',
                        help='print only top level directory(ies) in text format',
                        default=False)

    parser.add_argument('-f', '--files',
                        dest='files',
                        action='store_true',
                        help='output license information per file instead of per dir',
                        default=False)

    parser.add_argument('-ic', '--include-copyrights',
                        dest='include_copyrights',
                        action='store_true',
                        help='output copyright information',
                        default=False)

    parser.add_argument('-j', '--json',
                        dest='json_format',
                        action='store_true',
                        help='output in JSON',
                        default=False)

    parser.add_argument('-el', '--excluded-licenses',
                        dest='excluded_licenses',
                        type=str,
                        nargs="+",
                        help="excluded licenses (if set, remove file/dir from printout)",
                        default=None)

    parser.add_argument('-x', '--exclude',
                        dest='excluded_regexps',
                        type=str,
                        nargs="+",
                        help="exclud files and dirs matching the supplied patterns",
                        default=None)

    args = parser.parse_args()

    return args

def exclude_file(file_name, excluded_regexps):
    if excluded_regexps != None:
        for exp in excluded_regexps:
            if exp in file_name:
                #print("Excluding : " + file_name)
                return True
    return False

def exact_match(license_name, excluded_licenses):
    if excluded_licenses != None:
        for lic in excluded_licenses:
            #print(license_name + " matches " + lic + " ?????")
            if lic == license_name:
                return True
    return False

def collect_license_dir(report, dir, args, dirs_info, files_info):
    files              = args.files
    include_copyrights = args.include_copyrights
    excluded_licenses   = args.excluded_licenses    


    file_count = 0 
    
    for file in report['files']:

        file_name = file['path']
        file_type = file['type']

        # If file_name matches the exclude pattern, continue with next
        # loop iteration
        if exclude_file(file_name, args.excluded_regexps):
            continue
        
        file_info = {}
        file_lic_info = set()
        file_c_info = set()


        
        is_file = file_type == 'file'

        if file['path'].startswith(dir):
            file_info['path'] = file_name
            file_info['type'] = file_type
            file_info['licenses'] = []

            file_count += 1
            
            if include_copyrights:
                file_info['copyrights'] = set()
                for c in file['copyrights']:
                    copy_key = c['value']
                    file_info['copyrights'].add(copy_key)

            if file['licenses'] == None or file['licenses'] == []:
                file_info['licenses'] = [ UNKNOWN_LICENSE ]
            else:
                file_info['licenses'] = set()
                for lic_val in file['license_expressions']:
                    #print (file_name + "   lic_val: " + lic_val + "  ????")
                    if excluded_licenses == None or not exact_match(lic_val, excluded_licenses):
                        #print("Adding license: " + str(lic_val))
                        file_info['licenses'].add(lic_val)
                    else:
                        #print(file_name + " No .. since: " + lic_val + " in " + str(lic_val in excluded_licenses) + " " + str(excluded_licenses))
                        pass
                    
            if is_file:
                files_info[file_name] = file_info

                # Fill in this file's information in corresponding dirs (recursively)
                # - get dir name of file
                dir_name = os.path.dirname(file_name)
                while dir_name != "":
                    head, tail = os.path.split(dir_name)
                    dir_name = head
                    # - create dir info
                    if dir_name not in dirs_info:
                        dirs_info[dir_name] = {}
                        dirs_info[dir_name]['path'] = dir_name
                        dirs_info[dir_name]['licenses'] = set()
                        dirs_info[dir_name]['copyrights'] = set()
                    #print("Adding to " + dir_name + " <--- " + str(file_info['licenses']))
                    dirs_info[dir_name]['licenses'].update(file_info['licenses'])
                    #print("Adding to " + dir_name + " <--- " + str(dirs_info[dir_name]['licenses']))
                    if include_copyrights:
                        dirs_info[dir_name]['copyrights'].update(file_info['copyrights'])

    #print(dir + " checked " + str(file_count) + " files")
                        
    if files:
        return files_info
    else:
        return dirs_info
    
def output_license_per_dir(report, args):
    
    files             = args.files

    files_info = {}
    dirs_info = {}
    
    nr = 0
    #tmp = [ report['files'][91], report['files'][0] ]
    for file in report['files']:
    #for file in tmp:
        #print("type: " + file['type'] + " " + file['path'] + " " + str(nr))
        nr += 1
        if file['type'] == 'directory':
            collect_license_dir(report, file['path'], args, dirs_info, files_info)
    #print("==========================================================" + str(files_infos))

    if args.files:
        return files_info
    else:
        return dirs_info

def main():
    args = parse()

    with open(args.file) as fp:
        report = json.load(fp)

    if args.dir:
        result = collect_license_dir(report, args.dir, args)
    else:
        result = output_license_per_dir(report, args)

    if result != None:
        if args.json_format:
            print(json.dumps(result))
        else:
            for k,v in result.items():

                # If dir and top-level
                if not args.files and args.top_level:
                    if "/" in k:
                        continue
                    
                l_fmt = "%-40s: %s %s"
                lic = list(v['licenses'])
                if lic == [] and args.files:
                    continue
                if args.include_copyrights:
                    cop = v['copyrights']
                else:
                    cop=""
                res_str = str(l_fmt) % ( k, lic, cop)
                print(res_str)
    else:
        print("")
        
#                l_fmt = "%-40s: %s %s"
#                lic_c_str = str(l_fmt) % ( dir, set_str, c_set_str)

    
if __name__ == '__main__':
    main()
    
