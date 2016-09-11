if(!settings.multipleView) settings.batchView=false;
settings.tex="pdflatex";
defaultfilename="linear-9";
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
    return 0.5*x-2;
}

real f2(real x)
{
    return -3*x+5;
}

draw(graph(f1, -10, 10), purple);
draw(graph(f2, -1, 4), red);

label("$y=0.5x-2$",  ( 5, f1(5)), N*4, purple);
label("$y=-3x+5$",   ( 3, f2(3)), E, red);

xaxis("$x$", RightTicks(NoZero));
yaxis("$y$", LeftTicks(NoZero));

//fixedscaling((-0.5, -6), (4, 6));
