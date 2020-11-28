
DOT_FILES=yocto-tools.dot files.dot
MD_FILES=yocto-tool-suite.md

PNG_FILES=${DOT_FILES:dot=png}
JPG_FILES=${DOT_FILES:dot=jpg}
PDF_FILES=${DOT_FILES:dot=pdf} ${MD_FILES:md=pdf} 

ALL_FORMAT_FILES=$(PNG_FILES) $(JPG_FILES) $(PDF_FILES) 

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

all: $(ALL_FORMAT_FILES)

$(ALL_FORMAT_FILES): $(MD_FILES) $(DOT_FILES) Makefile 


clean:
	rm $(ALL_FORMAT_FILES) *~

