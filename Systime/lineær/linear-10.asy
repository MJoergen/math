if(!settings.multipleView) settings.batchView=false;
settings.tex="pdflatex";
defaultfilename="linear-10";
if(settings.render < 0) settings.render=4;
settings.outformat="";
settings.inlineimage=true;
settings.embed=true;
settings.toolbar=false;
viewportmargin=(2,2);

size(0,200);

import graph;

real f1(real x)
{
    return 1.6*x+1;
}

pair p0 = (1,2);
pair p1 = (2,5);
pair p2 = (3,6);
pair p3 = (4,7);

dot(p0);
dot(p1);
dot(p2);
dot(p3);

draw(graph(f1, -0.5, 5));

xaxis("$x$", RightTicks(new real[]{1,2,3,4,5}));
yaxis("$y$", LeftTicks(NoZero, n=1));

//fixedscaling((-0.5, -6), (4, 6));
