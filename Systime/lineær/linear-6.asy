if(!settings.multipleView) settings.batchView=false;
settings.tex="pdflatex";
defaultfilename="linear-6";
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

pair p0 = (0.0, f1(0.0));
pair p1 = (1.0, f1(1.0));
pair p2 = (2.0, f1(2.0));
pair p3 = (3.0, f1(3.0));

draw(graph(f1,  0, 4), blue);
dot(p0);
dot(p1);
dot(p2);
dot(p3);

label("$y=3x-5$",  ( 0.5, f1( 0.5)), E, blue);
label("$(0, -5)$", p0, E, black);
label("$(1, -2)$", p1, E, black);
label("$(2,  1)$", p2, E, black);
label("$(3,  4)$", p3, E, black);

xaxis("$x$", RightTicks(Label(align=right), new real[]{-2,2,4}, new real[]{-1,1,3}),EndArrow);
yaxis("$y$", LeftTicks(NoZero),EndArrow);

fixedscaling((-0.5, -6), (4, 6));
