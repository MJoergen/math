names  = lineær.tex
names += eksp.tex
names += eksp2.tex
tex_pdfs   = $(names:.tex=.pdf)

pics   = eksp-b.asy
pics  += eksp-a.asy
pics  += eksp-c.asy
pics  += eksp-d.asy
pics  += linear-1.asy
pics  += linear-2.asy
pics  += linear-3.asy
asy_pdfs  += $(pics:.asy=.pdf)

all: $(asy_pdfs) $(tex_pdfs)

%.pdf : %.asy
	asy $< 

%.pdf : %.tex
	latexmk -pdf $<

clean:
	rm -f *.log *.aux *.pdf *.pre *.toc *.fdb_latexmk *.fls

