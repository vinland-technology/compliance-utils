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

### List licenses

If you want a list of the licenses (discarding ```&``` and ```|```) in
the image built with Yocto you can use the following command, after
having run yoga.

```
$ for f in $(find compliance-results/*/*-component.json -prune ); do jq .license $f; done | sed 's, ,,g' | sort | uniq -c | sort -rnk1
```

### List licenses and their packages

```
unset LIC_MAP; declare -A LIC_MAP; for f in $(find compliance-results/*/*-component.json -prune ); do PKG=$(jq '.package' $f); LIC=$(jq '.license' $f | sed -e 's,[|&\"()], ,g'); for lic in $LIC; do echo "ADD $lic $PKG"; LIC_MAP[$lic]="${LIC_MAP[$lic]} $PKG"; done ; done ; echo "----------------"; for i in "${!LIC_MAP[@]}"; do   echo -n "$i:";   echo "${LIC_MAP[$i]}"; done | sort
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

