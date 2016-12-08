if(!settings.multipleView) settings.batchView=false;
settings.tex="pdflatex";
defaultfilename="linear-4";
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
    return 20.0 + 0.5*x;
}

draw("$y=20+0,\!5x$", graph(f1, 0, 20), red);

xaxis("min.",RightTicks(Label(align=left), NoZero),EndArrow);
yaxis("kr.",LeftTicks(NoZero),EndArrow);
