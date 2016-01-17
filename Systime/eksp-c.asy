if(!settings.multipleView) settings.batchView=false;
settings.tex="pdflatex";
defaultfilename="eksp-c";
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
    return exp(log(0.7)*x);
}

real f2(real x)
{
    return exp(log(1.4)*x);
}

pair F1(real x) {return (x,f1(x));}
pair F2(real x) {return (x,f2(x));}

draw(graph(f1, -3, 3), red);
draw(graph(f2, -3, 3), blue);

label("$a<0$", F1(-2.0), NE);
label("$a>0$", F2(2.0), NW);

xaxis("$x$",RightTicks(Label(align=left), NoZero));
yaxis("$y$",LeftTicks(NoZero));
