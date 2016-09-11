if(!settings.multipleView) settings.batchView=false;
settings.tex="pdflatex";
defaultfilename="eksp-b";
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
    return 4.7*exp(log(0.91)*x);
}

real f2(real x)
{
    return 3.1*exp(log(1.4)*x);
}

draw("$y=4,7\cdot 0,91^x$", graph(f1, -3, 4), red);
draw("$y=3,1\cdot 1,4^x$", graph(f2, -3, 3), blue);

xaxis("$x$",RightTicks(Label(align=left), NoZero));
yaxis("$y$",LeftTicks(NoZero));
