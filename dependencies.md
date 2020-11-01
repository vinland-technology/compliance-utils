# NAME

   dependencies.sh - list dependencies recursively

# SYNOPSIS
   ```dependencies.sh [OPTIONS] FILE```



# DESCRIPTION
   List dependencies recursively foe the given file. The files can be
   either a program (name of with path) or a library (name or with path)
   If the supplied file does not have path we do our best trying to find it
   using which or (internal function) findllib.

# OPTIONS
## Library related options
```-e, --ELF```


use readelf to find dependencies. Default.

```--ldd```


use ldd to find dependencies. Default is readelf.

```--objdump```


use objdump to find dependencies. Default is readelf.

```--lib-dir DIR```


adds DIR to directories to search for libraries. For every use of this option
the directories are added. If no directory is specified the default directories
are: 

## Format options
```--dot```


create dot like file (in output dir). Autmatically adds: "-s" and "-l" 

```--pdf```


create pdf file (in output dir). Autmatically adds: "-s" and "-l" 

```--png```


create png file (in output dir). Autmatically adds: "-s" and "-l" 

```--svg```


create svg file (in output dir). Autmatically adds: "-s" and "-l" 

```--png```


create pdf file (in output dir). Autmatically adds: "-s" and "-l" 

## Output options
```--outdir, -od DIR```


output logs to DIR. Default is ~/.vinland/elf-deps

```-av, --auto-view```


open (using xdg-open) the first formats produced

```--long```


output directory name with path

```-l, --log```


store log in outpur dir, as well as print to stdout

```-s, --silent```


do not print to stdout

```-u, --uniq```


print uniq dependencies in alphabetical order. 
Sets txt more and disables everything else.

# EXAMPLES
```dependencies.sh evince```


lists all dependencies for the program evince

```dependencies.sh --pdf libcairo2.so```


lists all dependencies for the library libcairo2.so and creates report in pdf format

# EXIT CODES

```0 - success```


```1 - could not find file```


```2 - file not in ELF format```


```3 - silent and no logging not vailed```


```4 - unknown or unsupported format```


```6 - unsupported host operating system```



# AUTHOR
Written by Henrik Sandklef

# REPORTING BUGS
Add an issue at https://github.com/vinland-technology/compliance-utils

# COPYRIGHT & LICENSE
Copyright 2020 Henrik Sandklef
License GPL-3.0-or-later
