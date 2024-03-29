names += elliptic.tex
names += fjerde.tex
names += pell.tex
names += pendulum.tex
names += tredje.tex
names += euler.tex

tex_pdfs   = $(names:.tex=.pdf)

%pics   = fig1.asy
%asy_pdfs  += $(pics:.asy=.pdf)

all: $(asy_pdfs) $(tex_pdfs)

%.pdf : %.asy
	asy $< 

%.pdf : %.tex
	latexmk -pdf $<

clean:
	rm -f *.log *.aux *.pdf *.pre *.toc *.fdb_latexmk *.fls

