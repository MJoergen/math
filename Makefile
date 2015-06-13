names = opg24-page3075.tex
names += opg25-page3075.tex
names += opg27-page3075.tex

pdfs = $(names:.tex=.pdf)

all: $(pdfs)

%.pdf : %.tex
	latexmk -pdf $<

clean:
	rm -f $(NAME).log $(NAME).aux $(NAME)*.pdf $(NAME)*.asy $(NAME).pre $(NAME).toc $(NAME).fdb_latexmk $(NAME).fls


