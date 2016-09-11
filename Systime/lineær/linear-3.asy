if(!settings.multipleView) settings.batchView=false;
settings.tex="pdflatex";
defaultfilename="linear-3";
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
    return 0.4*(x-4.0)+5.0;
}

pair F1(real x)
{
    return (x, f1(x));
}

pair pa = F1(-1.0);
pair pb = F1(4.0);

dot(pa);
dot(pb);

label("A", pa, NW);
label("B", pb, NW);
label("$(-1, 3)$", pa, SE);
label("$(4, 5)$", pb, SE);

draw(graph(f1, -2, 5), red);

xaxis("$x$",NoTicks);
yaxis("$y$",NoTicks);

