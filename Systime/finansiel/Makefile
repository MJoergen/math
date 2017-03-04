names  = finansiel.tex
tex_pdfs   = $(names:.tex=.pdf)

pics += eksp-f.asy
asy_pdfs  += $(pics:.asy=.pdf)

all: $(asy_pdfs) $(tex_pdfs)

%.pdf : %.asy
	asy $< 

%.pdf : %.tex $(asy_pdfs)
	latexmk -pdf $<

clean:
	rm -f *.log *.aux *.pdf *.pre *.toc *.fdb_latexmk *.fls

