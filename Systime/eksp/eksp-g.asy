import unicode;
if(!settings.multipleView) settings.batchView=false;
settings.tex="pdflatex";
defaultfilename="eksp-g";
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
    return 2154.74*exp(log(1.35214)*x);
}

pair p0 = (0.0, 2180);
pair p1 = (1.0, 2955);
pair p2 = (2.0, 3698);
pair p3 = (3.0, 5530);

dot(p0);
dot(p1);
dot(p2);
dot(p3);

// draw("$f(x) = 2155 \cdot 1,\!35^x$", graph(f1, 0, 4), red);

xaxis("$x$", RightTicks(Label(align=left), NoZero));
yaxis("$y$", LeftTicks(NoZero));

// fixedscaling((-0.5, -500), (4.5, 6000));
