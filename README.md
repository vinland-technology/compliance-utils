# Compliance Utils

Misc small utils in your every day compliance work

## Yocto related tools

### yoda

yoda analyses various files produced during a Yocto build and produces either:

* a list of packages that is put in to the image built

* a file containing information about packages 

This tool is used by *yoda*, which probably is the tool you should
look into.

### yoga

*yoga* invokes *yoda* to create a list of image packages 

For each package in this files:

* invokes yoda to analyse the package and collect relevant compliance information 

* invokes flict to do license compatibility check on the package

* collects source code

* collects copyright and license information

* creates a graph, in various formats, over the package and its dependencies

### yocr

yocr creates a report summarising the compliance result from yocr. The
report can be created for humans (html) and computers (JSON).

## Misc tricks

If you want a list of the licenses (discarding ```&``` and ```|```) in
the image built with Yocto you can use the following command, after
having run yoga.

```
$ for j in $(find compliance-results/ -name "*tree-flict.json"); do jq .component.license $j; done  | sed -e 's,",,g' -e "s,[&|\(\) ],\n,g" | grep -v "^[ ]*$" |  sort | uniq -c | sort -rnk1
     59 MIT
     43 GPLv2+
     43 BSD
     36 LGPLv2.1+
     36 LGPLv2.1
     36 LGPLv2+
     30 GPLv2
     27 PD
     27 MIT-style
     20 GPLv3+
     16 LGPLv2
     15 BSD-3-Clause
     14 Artistic-1.0
     12 LGPLv3+
     10 AFL-2.1
      6 LGPLv2.0+
      6 LGPL-2.1+
      3 openssl
      3 ICU
      3 BSD-4-Clause
      2 MPL-1.1
      2 GPL-3.0-with-GCC-exception
      2 bzip2-1.0.6
      1 Zlib
      1 Libpng
      1 LGPLv3
      1 GPLv2.0+
      1 FreeType
      1 BSD-2-Clause
```

## dependencies.sh

List dependencies recursively foe the given file. The files can be
either a program (name of with path) or a library (name or with path)
If the supplied file does not have path we do our best trying to find
it using which or (internal function) findllib.

script: [```dependencies.sh``` ](https://github.com/vinland-technology/compliance-utils/blob/main/bin/dependencies.sh)

manual: [```dependencies.md``` ](dependencies.md)



## yocto-build-to-flict.sh

This script is being replaced by yoda.py 

List information about packages from a Yocto build. The output is
designed to be used by flict (link below)

script: [```yocto-build-to-flict.sh``` ](https://github.com/vinland-technology/compliance-utils/blob/main/bin/yocto-build-to-flict.sh)

manual: [```yocto-build-to-flict.md``` ](yocto-build-to-flict.md)

## yocto-compliance.sh

