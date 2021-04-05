# Compliance Utils

Misc small utils in your every day compliance work

## Yocto related tools

<a name="yoga"></a>
### yoga

yoga invokes miscellaneous tools to create a list of image packages
 and useful compliance information.

For each package in this files:

* analyse (with [_yoda_](#yoda)) the package and collect relevant compliance information 

* invokes [flict](https://github.com/vinland-technology/flict) (and [_yoda2flict_](#yoda2flict)) to do license compatibility checks on the packages

* collects source code (beta)

* collects copyright and license information

* creates graphs (with [_flict-to-dot_](#flict-to-dot)) in various formats over the package and their dependencies

Help text: [yoga.txt](doc/generated/yoga.txt)

<a name="yoda"></a>
### yoda

yoda analyses various files produced during a Yocto build and produces:

* a list of packages that is put in to the image built

* a file containing information (e.g dependencies) about packages 

This tool is used by [_yoga_](#yoga), which probably is the tool you should
look into. Help text: [yoda.txt](doc/generated/yoda.txt)

#### Examples

Create a JSON file with all packages and image packages (sub packages) for image core-image-minimal
```
    yoda -c yoda.conf list
```

Create JSON files for all Cairo's 
```
    yoda -c yoda.conf -p cairo exportpackagel
```

Create JSON files for Cairo's imagepackage cairo-gobject
```
    yoda -c yoda.conf -p cairo -sp cairo-gobject exportpackagel
```

<a name="yocr"></a>
### yocr

yocr creates a report summarising the compliance result from yocr. The
report can be created for humans (html) and computers (JSON).

<a name="yora"></a>
### yora

*This tool is under construction.* 

<a name="dependencies"></a>
## dependencies.sh

List dependencies recursively foe the given file. The files can be
either a program (name of with path) or a library (name or with path)
If the supplied file does not have path we do our best trying to find
it using which or (internal function) findllib. Help text: [dependencies.txt](doc/generated/dependencies.txt)

<a name="flict-to-dot"></a>
## flict-to-dot.sh

Takes a [flict](https://github.com/vinland-technology/flict) file and creates
a dit file (to create graph files). This useful when you want a
graphical representation of a project's dependencies. Help text: [flict-to-dot.txt](doc/generated/flict-to-dot.txt)

## reusew

Wrapper over [reuse](https://reuse.software/). Help text: [reusew.txt](doc/generated/reusew.txt)

<a name="scancode-analyser.py"></a>
## scancode-analyser.py

A tiny tool to assist when analysing a Scancode report

Help text: [scancode-analyser.txt](doc/generated/scancode-analyser.txt)

<a name="yoda2flict"></a>
## yoda2flict.py

Transforms the output from yoda in to a format
[flict](https://github.com/vinland-technology/flict) can use to check license
compatibility. Help text: [yoda2flict.txt](doc/generated/yoda2flict.txt)

