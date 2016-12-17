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

ticks xticks = RightTicks(scale(0.6)*Label(align=right), new real[]{1, 2, 3, 4}, Size=2);
ticks yticks = LeftTicks(scale(0.6)*Label(align=left), new real[]{-1, 1, 2, 3, 4, 5, 6, 7, 8}, Size=2);

xaxis(xticks, Arrow(HookHead), xmin=-1.5, xmax=5);
yaxis(yticks, Arrow(HookHead), ymin=-1.5, ymax=9);

xequals(-1, dotted);
xequals(1, dotted);
xequals(2, dotted);
xequals(3, dotted);
xequals(4, dotted);

yequals(-1, dotted);
yequals(1, dotted);
yequals(2, dotted);
yequals(3, dotted);
yequals(4, dotted);
yequals(5, dotted);
yequals(6, dotted);
yequals(7, dotted);
yequals(8, dotted);

label("$x$", (5, -0.2), align=SW, filltype=Fill(white));
label("$y$", (-0.2, 9), align=SW, filltype=Fill(white));

real f1(real x)
{
    return 1.6*x+1;
}

pair p0 = (1,2);
pair p1 = (2,5);
pair p2 = (3,6);
pair p3 = (4,7);

dot(p0);
dot(p1);
dot(p2);
dot(p3);

draw(graph(f1, -0.5, 5), blue_default);

