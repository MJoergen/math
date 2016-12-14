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

texpreamble("\usepackage[T1]{fontenc}");
texpreamble("\usepackage{verdana}");
defaultpen(font("T1","verdana","m","n"));

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


real f1(real x)
{
    return 3*x-5;
}

pair p0 = (0.0, f1(0.0));
pair p1 = (1.0, f1(1.0));
pair p2 = (2.0, f1(2.0));
pair p3 = (3.0, f1(3.0));

label("$x$", ( 5,    -0.3), align=SW);
label("$y$", (-0.125, 7),   align=SW);

ticks xticks = RightTicks(scale(0.6)*Label(align=right), new real[]{-1, 1, 2, 3, 4}, Size=2);
ticks yticks = LeftTicks(scale(0.6)*Label(align=left), new real[]{-5, -4, -3, -2, -1, 1, 2, 3, 4, 5, 6}, Size=2);

xaxis(xticks, Arrow(HookHead), xmin=-2, xmax=5);
yaxis(yticks, Arrow(HookHead), ymin=-6, ymax=7);

xequals(-2, dotted);
xequals(-1, dotted);
xequals(1, dotted);
xequals(2, dotted);
xequals(3, dotted);
xequals(4, dotted);
xequals(5, dotted);

yequals(-6, dotted);
yequals(-5, dotted);
yequals(-4, dotted);
yequals(-3, dotted);
yequals(-2, dotted);
yequals(-1, dotted);
yequals(1, dotted);
yequals(2, dotted);
yequals(3, dotted);
yequals(4, dotted);
yequals(5, dotted);
yequals(6, dotted);
yequals(7, dotted);

draw(graph(f1,  0, 4), blue_default);
dot(p0);
dot(p1);
dot(p2);
dot(p3);

label("$y=3x-5$",  ( 0.5, f1( 0.5)), 1.2E, blue_default, filltype=Fill(white));
label("$(0, -5)$", p0, 1.2E, black, filltype=Fill(white));
label("$(1, -2)$", p1, 1.2E, black, filltype=Fill(white));
label("$(2,  1)$", p2, 1.2E, black, filltype=Fill(white));
label("$(3,  4)$", p3, 1.2E, black, filltype=Fill(white));

fixedscaling((-0.5, -6), (4, 6));


