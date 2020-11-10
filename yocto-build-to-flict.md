NAME
   yocto-build-to-flict.sh

SYNOPSIS
   yocto-build-to-flict.sh [OPTION] package

DESCRIPTION
   List information about packages from a Yocto build. The output
   is designed to be used by flict (link below)

OPTIONS
   -bd, --build-dir <DIR>
      Sets the build dir to DIR 

   -i, --image <IMAGE>
      Sets the image dir to IMAGE 

   -mtd, --meta-top-dir <DIR>
      Sets the top level directory for meta files (e.g. bitbake recipes)

   -dd, --dist-dir <DIR>
      Sets the distribution directory to DIR

   -m, --machine <MACHINE>
      Sets the machine to MACHINE
      

   -d, --date <DATE>
      Set the date to DATE. This is needed to find license manifest

   -od, --out-dir <DIR>
      Set the output directory to DIR. Default is /home/hesa/.vinland/compliance-utils/artefacts

   -nl, --no-libc
      Exclude all libc related dependencies

   -v, --verbose
      Enable verbose output

   -sp, --split-package <SPLIT PACKAGE>
      List only split package (sub package) for the package. Do not list all split packages.

   -a, --artefect <ARTEFECT>
      Print information about ARTEFACT 

   -la, --list-artefacts
     List all artefacts or if package is set (before -la) list all artefacts for that package

   -ma, --manage-artefacts
     Print information about all artefacts. Warning, there be dragins here

    --help, h
      Prints this help text.

ENVIRONMENT VARIABLES
   The following environment variables can be used to tweak 

   DIST_DIR (see -dd). Default is "core2-64-poky-linux"

   MACHINE (see -m).  Default is "qemux86-64"

   IMAGE (see -i). Default is "core-image-minimal-qemux86-64"

   DATE (see -d). Default is "20201024110850"

   META_TOP_DIR (see -mtd).Default is "../"
   
EXAMPLES
   The examples below assume you have set the environment as desribed above

   $ yocto-build-to-flict.sh -a bsdtar
      Prints information about the split package bsdtar (from the package libarchive)

   $ yocto-build-to-flict.sh libarchive
      Prints information about the package libarchive

   $ yocto-build-to-flict.sh libarchive -sp bsdtar
      Prints information about the split package bsdtar from the package libarchive

   $ yocto-build-to-flict.sh libarchive -la
      List all artefacts

   $ yocto-build-to-flict.sh libarchive -la
      List all artefacts for libarchive

      Prints information about the package libarchive

AUTHOR
    Written by Henrik Sandklef.

REPORTING BUGS
    File an issue over at: https://github.com/vinland-technology/compliance-utils

COPYRIGHT
    Copyright © 2020 Henrik Sandklef
    License GPLv3+: GNU GPL  version  3  or  later
    <https://gnu.org/licenses/gpl.html>.
    This  is  free  software: you are free to change and redistribute it.  There is NO WARRANTY,
    to the extent permitted by law.

SEE ALSO
    flict: https://github.com/vinland-technology/flict

