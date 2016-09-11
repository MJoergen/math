if(!settings.multipleView) settings.batchView=false;
settings.tex="pdflatex";
defaultfilename="eksp-a";
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
    return exp(log(1.1)*x);
}

real f2(real x)
{
    return exp(log(1.4)*x);
}

real f3(real x)
{
    return exp(log(2.0)*x);
}

real f4(real x)
{
    return exp(log(0.9)*x);
}

real f5(real x)
{
    return exp(log(0.7)*x);
}

real f6(real x)
{
    return exp(log(0.5)*x);
}

draw("$a=1,1$", graph(f1, -3, 3), red);
draw("$a=1,4$", graph(f2, -3, 3), red);
draw("$a=2,0$", graph(f3, -3, 3), red);

draw("$a=0,9$", graph(f4, -3, 3), blue);
draw("$a=0,7$", graph(f5, -3, 3), blue);
draw("$a=0,5$", graph(f6, -3, 3), blue);

xaxis("$x$",RightTicks(Label(align=left), NoZero));
yaxis("$y$",LeftTicks(NoZero));
