names  = finansiel.tex
tex_pdfs   = $(names:.tex=.pdf)

pics += fin-1.asy
pics += fin-2.asy
pics += fin-3.asy
pics += fin-4.asy
asy_pdfs  += $(pics:.asy=.pdf)

all: $(asy_pdfs) $(tex_pdfs)

%.pdf : %.asy
	asy $< 

%.pdf : %.tex $(asy_pdfs)
	latexmk -pdf $<

clean:
	rm -f *.log *.aux *.pdf *.pre *.toc *.fdb_latexmk *.fls

