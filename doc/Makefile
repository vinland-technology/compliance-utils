###################################################################
#
# SPDX-FileCopyrightText: 2021 Henrik Sandklef
#
# SPDX-License-Identifier: GPL-3.0-or-later
#
###################################################################


DOT_FILES=yocto-tools.dot files.dot
MD_FILES=yocto-tool-suite.md

PNG_FILES=${DOT_FILES:dot=png}
JPG_FILES=${DOT_FILES:dot=jpg}
PDF_FILES=${DOT_FILES:dot=pdf} ${MD_FILES:md=pdf} 

PY_PROGS_TXT=./generated/scancode-analyser.txt ./generated/flict-to-dot.txt ./generated/yoda2flict.txt
SH_PROGS_TXT=./generated/dependencies.txt ./generated/manage-non-spdx.txt
PROGS_TXT=./generated/reusew.txt ./generated/yocr.txt ./generated/yoda.txt ./generated/yoga.txt ./generated/yora.txt 

ALL_FORMAT_FILES=$(PNG_FILES) $(JPG_FILES) $(PDF_FILES) $(HELP_FILES) $(PY_PROGS_TXT) $(SH_PROGS_TXT) $(PROGS_TXT)

all: $(ALL_FORMAT_FILES)

%.png:%.dot
	dot -Tpng -o $@ $<
	mogrify -geometry 80% $@

%.jpg:%.dot
	dot -Tjpg -o $@ $<

%.pdf:%.dot
	dot -Tpdf -o $@ $<

%.pdf:%.md
	pandoc -o $@ $<

%.html:%.md
	pandoc -o $@ $<

$(PY_PROGS_TXT):
	@for i in $(PY_PROGS_TXT); do \
		PROG=`echo $${i} | sed -e 's,generated,../bin,'g -e 's,\.txt,\.py,'g ` ; \
		mkdir -p generated; $${PROG} -h > $${i}; \
	done

$(SH_PROGS_TXT):
	@for i in $(SH_PROGS_TXT); do \
		PROG=`echo $${i} | sed -e 's,generated,../bin,'g -e 's,\.txt,\.sh,'g ` ; \
		mkdir -p generated; $${PROG} -h > $${i}; \
	done

$(PROGS_TXT):
	@for i in $(PROGS_TXT); do \
		PROG=`echo $${i} | sed -e 's,generated,../bin,'g -e 's,\.txt,,'g ` ; \
		mkdir -p generated; $${PROG} -h > $${i}; \
	done


$(ALL_FORMAT_FILES): $(MD_FILES) $(DOT_FILES) Makefile 


clean:
	rm $(ALL_FORMAT_FILES) *~

