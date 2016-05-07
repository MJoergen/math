import unicode;
if(!settings.multipleView) settings.batchView=false;
settings.tex="pdflatex";
defaultfilename="eksp-f";
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

pair p0 = (0.0, 1000);
pair p1 = (1.0, 1050);
pair p2 = (2.0, 1103);
pair p3 = (3.0, 1158);
pair p4 = (4.0, 1216);
pair p5 = (5.0, 1276);
pair p6 = (6.0, 1340);
pair p7 = (7.0, 1407);
pair p8 = (8.0, 1477);

dot(p0);
dot(p1);
dot(p2);
dot(p3);
dot(p4);
dot(p5);
dot(p6);
dot(p7);
dot(p8);

// draw("$f(x) = 2155 \cdot 1,\!35^x$", graph(f1, 0, 4), red);

xaxis("år",RightTicks(Label(align=left), NoZero));
yaxis("saldo",LeftTicks(NoZero));

// fixedscaling((-0.5, -500), (4.5, 6000));
