names  = lineær.tex
tex_pdfs   = $(names:.tex=.pdf)

pics  += lin-1.asy
pics  += lin-1a.asy
pics  += lin-2.asy
pics  += lin-3.asy
pics  += lin-3a.asy
pics  += lin-4.asy
pics  += lin-5.asy
pics  += lin-6.asy
pics  += lin-7.asy
pics  += lin-8.asy
pics  += lin-9.asy
pics  += lin-10.asy
pics  += lin-11.asy
pics  += lin-12.asy
asy_pdfs  += $(pics:.asy=.pdf)

all: $(asy_pdfs) $(tex_pdfs)

%.pdf : %.asy
	asy $< 

%.pdf : %.tex
	latexmk -pdf $<

clean:
	rm -f *.log *.aux *.pdf *.pre *.toc *.fdb_latexmk *.fls

