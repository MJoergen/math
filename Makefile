names = nummer82.tex

pdfs = $(names:.tex=.pdf)

all: $(pdfs)

%.pdf : %.tex
	latexmk -pdf $<

clean:
	rm -f *.log *.aux *.pdf *.asy *.pre *.toc *.fdb_latexmk *.fls


