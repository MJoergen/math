dirs  = cassette
dirs += elliptic
dirs += fjerde
dirs += pell
dirs += pendulum
dirs += tredje
dirs += euler
dirs += modular
dirs += quintic

tex_pdfs   = $(foreach d,$(dirs),$(d)/$(d).pdf)

%pics   = fig1.asy
%asy_pdfs  += $(pics:.asy=.pdf)

all: $(asy_pdfs) $(tex_pdfs)

%.pdf : %.asy
	asy $< 

%.pdf : %.tex
	latexmk -pdf -cd $<

clean:
	for d in $(dirs); do (cd $$d && rm -f *.log *.aux *.pdf *.pre *.toc *.fdb_latexmk *.fls); done

