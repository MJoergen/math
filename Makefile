names = opg24-page3075.tex
names += opg25-page3075.tex
names += opg27-page3075.tex
names += opg28-page3075.tex
names += opg29-page3075.tex
names += opg31-page3075.tex
names += geom100-page3093.tex
names += opg33-page3121.tex
names += opg36-page3121.tex

pdfs = $(names:.tex=.pdf)

all: $(pdfs)

%.pdf : %.tex
	latexmk -pdf $<

clean:
	rm -f *.log *.aux *.pdf *.asy *.pre *.toc *.fdb_latexmk *.fls


