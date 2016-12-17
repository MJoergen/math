//////////////////////////////////////////////////////////////////
// Begin preamble

if(!settings.multipleView) settings.batchView=false;
settings.tex="pdflatex";
if(settings.render < 0) settings.render=4;
settings.outformat="";
settings.inlineimage=true;
settings.embed=true;
settings.toolbar=false;
viewportmargin=(2,2);

size(7cm);

import graph;

texpreamble("\usepackage{MyriadPro}");
texpreamble("\usepackage{sfmath}");

pen blue_thin   = rgb("77afc3");
pen purple_thin = rgb("916fa2");
pen yellow_thin = rgb("f49e42");
pen green_thin  = rgb("6a9f7b");

pen blue_default   = blue_thin   + 1.0;
pen purple_default = purple_thin + 1.0;
pen yellow_default = yellow_thin + 1.0;
pen green_default  = green_thin  + 1.0;

// End preamble
//////////////////////////////////////////////////////////////////

ticks xticks = RightTicks(scale(0.6)*Label(align=right), new real[]{10, 20, 30, 40}, Size=2);
ticks yticks = LeftTicks(scale(0.6)*Label(align=left), new real[]{-10, 10, 20, 30, 40, 50, 60, 70}, Size=2);

xaxis(xticks, Arrow(HookHead), xmin=-15, xmax=60);
yaxis(yticks, Arrow(HookHead), ymin=-15, ymax=80);

xequals(10, dotted);
xequals(20, dotted);
xequals(30, dotted);
xequals(40, dotted);
xequals(50, dotted);
xequals(60, dotted);

yequals(10, dotted);
yequals(20, dotted);
yequals(30, dotted);
yequals(40, dotted);
yequals(50, dotted);
yequals(60, dotted);
yequals(70, dotted);
yequals(80, dotted);

label("min", (60, -2), align=SW, filltype=Fill(white));
label("kr",  (-2, 80), align=SW, filltype=Fill(white));

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

draw(graph(f1, 0, 50), blue_default);
dot(p0);
dot(p1);
dot(p2);
dot(p3);
dot(p4);
dot(p5);

label("$y=1\frac{1}{2}x$",  ( 5, 65), E, filltype=Fill(white));
label("$(20, 30)$", p2, SE, filltype=Fill(white));
label("$(28, 42)$", p3, SE, filltype=Fill(white));
label("$(36, 54)$", p4, NW, filltype=Fill(white));
label("$(44, 66)$", p5, NW, filltype=Fill(white));
draw(p4..(44,54), Dotted);
draw(p5..(44,54), Dotted);
draw(p0..(15,7.5), Dotted);
draw(p1..(15,7.5), Dotted);

label("$10$", (p0+(15,7.5))/2, S, filltype=Fill(white));
label("$15$", (p1+(15,7.5))/2, E, filltype=Fill(white));

label("$8$", (p4+(44,54))/2, S, filltype=Fill(white));
label("$12$", (p5+(44,54))/2, E, filltype=Fill(white));

fixedscaling((-10, -10), (60, 80));

