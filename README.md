# compliance-utils

Misc small utils in your every day compliance work

## dependencies.sh

List dependencies recursively foe the given file. The files can be
either a program (name of with path) or a library (name or with path)
If the supplied file does not have path we do our best trying to find
it using which or (internal function) findllib.

script: [```dependencies.sh``` ](https://github.com/vinland-technology/compliance-utils/blob/main/bin/dependencies.sh)

manual: [```dependencies.md``` ](dependencies.md)

## yoda.py

List information about packages from a Yocto build. The output is
designed to be used by flict. More information soon


## yocto-build-to-flict.sh

This script is being replaced by yoda.py 

List information about packages from a Yocto build. The output is
designed to be used by flict (link below)

script: [```yocto-build-to-flict.sh``` ](https://github.com/vinland-technology/compliance-utils/blob/main/bin/yocto-build-to-flict.sh)

manual: [```yocto-build-to-flict.md``` ](yocto-build-to-flict.md)

## yocto-compliance.sh

