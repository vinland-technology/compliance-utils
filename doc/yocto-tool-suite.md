# Yocto tools

Yocto provides more or less all information needed to do an automated
compliance verification on a build. With our tools we aim at making it
possible to automated compliance verification.

Our tools analyses a Yocto build and:

* collects necessary information from the build files and directories

* creates necessary files to adhere to the license obligations

* checks license compatibility

* produces a copliance report 

# Overview

## Tool overview

![Overview of Yocto tools](yocto-tools.png).

The picture above shows what input and output the tools have.

## yoda

yoda analyses various files produced during a Yocto build and produces either:

* a list of packages that is put in to the image built

* a file containing information about packages 

## yoga

*yoga* invokes *yoda* to create a list of image packages 

For each package in this files:

* invokes yoda to analyse the package and collect relevant compliance information 

* invokes flict to do license compatibility check on the package

* collects source code

* collects copyright and license information

* creates a graph, in various formats, over the package and its dependencies

## yocr

yocr creates a report summarising the compliance result from yocr. The
report can be created for humans (html) and computers (JSON).

## File overview

![Overview of Yocto files](files.png).

The picture above shows the most important files used by our tools. The files produced by Yocto are filled with gray.

The *image.manifest* files is used to get a list of all the packages that are put into the image.

For each such package the link *runtime-reverse* is used to find the sub package.

For the sub packages, the *files* (binaries for now) are analysed to find their dependencies and license information.

# Tools

## yoda

## yoga

## yocr

# Terminology

**image package** - a package as specified in the license.manifest file. The name in this file can differ slightly from the package name. 

**image.manifest** - a file created by Yocto during a build. This file contais a list of packages, their version and licenses. Example content:

```
gstreamer1.0-plugins-good-cairo corei7_64 1.16.2
libcairo-gobject2 corei7_64 1.16.0
libcairo-lic corei7_64 1.16.0
libcairo2 corei7_64 1.16.0
```

**package** - a set of files, typically coming from a FOSS project, see [Yocto manual](https://www.yoctoproject.org/docs/2.5/ref-manual/ref-manual.html#structure-build-tmp-work) for more infrmation.

**runtime-reverse** - a link which links together the package name (e.g. *libcairo-gobject2*) as found in the *image.manifest* file with a sub package name (e.g *libcairo-gobject*). An example of such a link can be found below:

```
$ readlink pango/1.44.7-r0/pkgdata-sysroot/runtime-reverse/libcairo-gobject2
../runtime/cairo-gobject
```

**sub package** - a packge can consist of smaller units, called sub packages, see [Yocto manual](https://www.yoctoproject.org/docs/2.5/ref-manual/ref-manual.html#structure-build-tmp-work) for more infrmation.


