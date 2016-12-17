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

draw(graph(f1,  0, 5), blue_default);
draw(graph(f2, -4, 3), purple_default);
draw(graph(f3, -5, 9), yellow_default);
draw(graph(f4, -2, 3), green_default);

label("$x$", (10,    -0.25), align=SW);
label("$y$", (-0.25, 10),    align=SW);

ticks xticks = RightTicks(scale(0.6)*Label(align=right), new real[]{-6, -4, -2, 2, 4, 6, 8}, Size=2);
ticks yticks = LeftTicks(scale(0.6)*Label(align=left), new real[]{-6, -4, -2, 2, 4, 6, 8}, Size=2);

xaxis(xticks, Arrow(HookHead), xmin=-8, xmax=10);
yaxis(yticks, Arrow(HookHead), ymin=-6, ymax=10);

xequals(-8, dotted);
xequals(-6, dotted);
xequals(-4, dotted);
xequals(-2, dotted);
xequals(2, dotted);
xequals(4, dotted);
xequals(6, dotted);
xequals(8, dotted);
xequals(10, dotted);

yequals(-6, dotted);
yequals(-4, dotted);
yequals(-2, dotted);
yequals(2, dotted);
yequals(4, dotted);
yequals(6, dotted);
yequals(8, dotted);
yequals(10, dotted);

label("$y=3x-5$",  ( 4.0, f1( 4.0)), E, blue_default, filltype=Fill(white));
label("$y=-2x+1$", (-1.5, f2(-1.5)), SW, purple_default, filltype=Fill(white));
label("$y=4-x$",   ( 8.0, f3( 8.0)), SW, yellow_default, filltype=Fill(white));
label("$y=3x$",    (-1.0, f4(-1.0)), W, green_default, filltype=Fill(white));

