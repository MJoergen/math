if(!settings.multipleView) settings.batchView=false;
settings.tex="pdflatex";
defaultfilename="linear-5";
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
    return 3*x-5;
}

real f2(real x)
{
    return -2*x+1;
}

real f3(real x)
{
    return 4-x;
}

real f4(real x)
{
    return 3*x;
}

draw(graph(f1,  0, 5), blue);
draw(graph(f2, -4, 3), red);
draw(graph(f3, -5, 9), black);
draw(graph(f4, -2, 3), purple);

label("$y=3x-5$",  ( 4.0, f1( 4.0)), E, blue);
label("$y=-2x+1$", (-1.5, f2(-1.5)), W, red);
label("$y=4-x$",   ( 8.0, f3( 8.0)), W, black);
label("$y=3x$",    (-1.0, f4(-1.0)), W, purple);

xaxis("$x$", RightTicks(Label(align=left), NoZero));
yaxis("$y$", LeftTicks(NoZero));
