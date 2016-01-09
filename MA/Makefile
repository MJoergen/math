names  = nummer82.tex
names += opg1.tex
names += opg2.tex
names += opg3.tex
names += opg4.tex
names += opg5.tex
names += opg6.tex
names += opg19.tex
names += side3168.tex
names += side3172.tex
names += opg321.tex
names += opg322.tex
names += opg324.tex
names += opg103.tex
tex_pdfs   = $(names:.tex=.pdf)

pics   = fig1.asy fig3.asy
asy_pdfs  += $(pics:.asy=.pdf)

all: $(asy_pdfs) $(tex_pdfs)

%.pdf : %.asy
	asy $< 

%.pdf : %.tex
	latexmk -pdf $<

clean:
	rm -f *.log *.aux *.pdf *.pre *.toc *.fdb_latexmk *.fls

