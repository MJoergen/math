if(!settings.multipleView) settings.batchView=false;
settings.tex="pdflatex";
defaultfilename="eksp-d";
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
    return 486.0*exp(log(1.0/3.0)*x);
}

pair p1 = (5.0,  2.0);
pair p2 = (3.0, 18.0);

dot(p1);
dot(p2);

draw("$f(x) = 486\cdot\left(\frac{1}{3}\right)^x$", graph(f1, 2.5, 6), red);

xaxis("$x$",RightTicks(Label(align=left), NoZero));
yaxis("$y$",LeftTicks(NoZero));
