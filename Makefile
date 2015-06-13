NAME = opg24-page3075

all: $(pdfs)
	echo pdflatex $(NAME).tex
	latexmk -pdf $(NAME)

clean:
	rm -f $(NAME).log $(NAME).aux $(NAME)*.pdf $(NAME)*.asy $(NAME).pre $(NAME).toc $(NAME).fdb_latexmk $(NAME).fls


