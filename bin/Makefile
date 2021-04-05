###################################################################
#
# SPDX-FileCopyrightText: 2021 Henrik Sandklef
#
# SPDX-License-Identifier: GPL-3.0-or-later
#
###################################################################

all:  ../yocto-build-to-flict.md ../dependencies.md

../dependencies.md: dependencies.sh
	./dependencies.sh --markdown-help > $@
	git commit -m "new version from ./dependencies.sh --markdown-help" $@

../yocto-build-to-flict.md: yocto-build-to-flict.sh
	./yocto-build-to-flict.sh -h > $@
	git commit -m "new version from ./yocto-build-to-flict.sh -h" $@

