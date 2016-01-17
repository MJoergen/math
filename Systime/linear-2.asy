if(!settings.multipleView) settings.batchView=false;
settings.tex="pdflatex";
defaultfilename="linear-2";
if(settings.render < 0) settings.render=4;
settings.outformat="";
settings.inlineimage=true;
settings.embed=true;
settings.toolbar=false;
viewportmargin=(2,2);

size(200, IgnoreAspect);

import graph;

pair pa = (3.0, 1.0);
pair pb = (3.0, 6.0);

dot(pa);
dot(pb);

draw(pa..pb);

label("A", pa, W);
label("B", pb, W);
label("$(x_1,y_1)$", pa, E);
label("$(x_2,y_2)$", pb, E);

xaxis("$x$",NoTicks);
yaxis("$y$",NoTicks);

