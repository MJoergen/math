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

ticks xticks = RightTicks(scale(0.6)*Label(align=right), new real[]{-4, -2, 2, 4, 6}, Size=2);
ticks yticks = LeftTicks(scale(0.6)*Label(align=left), new real[]{-6, -4, -2, 2, 4, 6}, Size=2);

xaxis(xticks, Arrow(HookHead), xmin=-5, xmax=9);
yaxis(yticks, Arrow(HookHead), ymin=-7, ymax=8);

xequals(-4, dotted);
xequals(-2, dotted);
xequals(2, dotted);
xequals(4, dotted);
xequals(6, dotted);
xequals(8, dotted);

yequals(-6, dotted);
yequals(-4, dotted);
yequals(-2, dotted);
yequals(2, dotted);
yequals(4, dotted);
yequals(6, dotted);
yequals(8, dotted);

label("$x$", (9, -0.4), align=SW, filltype=Fill(white));
label("$y$", (-0.4, 8), align=SW, filltype=Fill(white));

real f1(real x)
{
    return 0.5*x-2;
}

real f2(real x)
{
    return -3*x+4;
}

draw(graph(f1, -5, 9), blue_default);
draw(graph(f2, -1.3, 3.6), purple_default);

label("$y=0.5x-2$",  ( 5, f1(5)), N*6, blue_default, filltype=Fill(white));
label("$y=-3x+4$",   ( 3, f2(3)), E*2, purple_default, filltype=Fill(white));

