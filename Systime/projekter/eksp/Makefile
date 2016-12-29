names = eksp.tex
tex_pdfs   = $(names:.tex=.pdf)

pics  += kva1.asy
pics  += kva2.asy
pics  += kva3.asy
pics  += kva4.asy
asy_pdfs  += $(pics:.asy=.pdf)

all: $(asy_pdfs) $(tex_pdfs)

%.pdf : %.asy
	asy $< 

%.pdf : %.tex $(asy_pdfs)
	latexmk -pdf $<

clean:
	rm -f *.log *.aux *.pdf *.pre *.toc *.fdb_latexmk *.fls

