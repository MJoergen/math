if(!settings.multipleView) settings.batchView=false;
settings.tex="pdflatex";
defaultfilename="linear-8";
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
    return 1.5*x;
}

pair p0 = ( 5.0, f1( 5.0));
pair p1 = (15.0, f1(15.0));
pair p2 = (20.0, f1(20.0));
pair p3 = (28.0, f1(28.0));
pair p4 = (36.0, f1(36.0));
pair p5 = (44.0, f1(44.0));

draw(graph(f1, 0, 50));
dot(p0);
dot(p1);
dot(p2);
dot(p3);
dot(p4);
dot(p5);

label("$y=1\frac{1}{2}x$",  ( 5, 65), E);
label("$(20, 30)$", p2, SE);
label("$(28, 42)$", p3, SE);
label("$(36, 54)$", p4, NW);
label("$(44, 66)$", p5, NW);
draw(p4..(44,54), dotted);
draw(p5..(44,54), dotted);
draw(p0..(15,7.5), dotted);
draw(p1..(15,7.5), dotted);

label("$10$", (p0+(15,7.5))/2, S);
label("$15$", (p1+(15,7.5))/2, E);

label("$8$", (p4+(44,54))/2, S);
label("$12$", (p5+(44,54))/2, E);

xaxis("min", RightTicks(new real[]{10,20,30,40,50}));
yaxis("km", LeftTicks(NoZero));

fixedscaling((-10, -10), (60, 80));
