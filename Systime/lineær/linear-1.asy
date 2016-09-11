if(!settings.multipleView) settings.batchView=false;
settings.tex="pdflatex";
defaultfilename="linear-1";
if(settings.render < 0) settings.render=4;
settings.outformat="";
settings.inlineimage=true;
settings.embed=true;
settings.toolbar=false;
viewportmargin=(2,2);

size(200, IgnoreAspect);

import graph;

real f1(real x)
{
    return 0.5*x+2;
}

pair F1(real x)
{
    return (x, f1(x));
}

pair pa  = (1.0, 2.5);
pair pb  = (4.0, 4.0);
pair pay = (0.0, 2.5);
pair pby = (0.0, 4.0);
pair pax = (1.0, 0.0);
pair pbx = (4.0, 0.0);

dot(pa);
dot(pb);

draw(pay..pa, dotted);
draw(pby..pb, dotted);
draw(pax..pa, dotted);
draw(pbx..pb, dotted);

label("$y_1$", pay, W);
label("$y_2$", pby, W);
label("$x_1$", pax, S);
label("$x_2$", pbx, S);

label("A", pa, NW);
label("B", pb, NW);
label("$(x_1,y_1)$", pa, SE);
label("$(x_2,y_2)$", pb, SE);

draw(graph(f1, -1, 5), red);

xaxis("$x$",NoTicks);
yaxis("$y$",NoTicks);

