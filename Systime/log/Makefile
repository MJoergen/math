names += log.tex
tex_pdfs   = $(names:.tex=.pdf)

pics += log1.asy
pics += log2.asy
pics += log3.asy
asy_pdfs  += $(pics:.asy=.pdf)

all: $(asy_pdfs) $(tex_pdfs)

%.pdf : %.asy
	asy $< 

%.pdf : %.tex $(asy_pdfs)
	latexmk -pdf $<

clean:
	rm -f *.log *.aux *.pdf *.pre *.toc *.fdb_latexmk *.fls

