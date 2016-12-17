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

size(7cm, 7cm, IgnoreAspect);

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

label("$x$", ( 5,    -0.25), align=SW);
label("$y$", (-0.25, 9),   align=SW);

ticks xticks = RightTicks(scale(0.6)*Label(align=right), new real[]{-4, -3, -2, -1, 1, 2, 3, 4}, Size=2);
ticks yticks = LeftTicks(scale(0.6)*Label(align=left), new real[]{1, 2, 3, 4, 5, 6, 7, 8}, Size=2);

xaxis(xticks, Arrow(HookHead), xmin=-5, xmax=5);
yaxis(yticks, Arrow(HookHead), ymin=-1, ymax=9);

xequals(-4, dotted);
xequals(-3, dotted);
xequals(-2, dotted);
xequals(-1, dotted);
xequals(1, dotted);
xequals(2, dotted);
xequals(3, dotted);
xequals(4, dotted);

yequals(1, dotted);
yequals(2, dotted);
yequals(3, dotted);
yequals(4, dotted);
yequals(5, dotted);
yequals(6, dotted);
yequals(7, dotted);
yequals(8, dotted);

real f1(real x)
{
    return 4.7*exp(log(0.91)*x);
}

real f2(real x)
{
    return 3.1*exp(log(1.4)*x);
}

draw(graph(f1, -4.5, 4.5), blue_default);
draw(graph(f2, -4.5, 3), purple_default);

label("$y=4,\!7\cdot 0,\!91^x$", (-3, 4.5), blue_default, Fill(white));
label("$y=3,\!1\cdot 1,\!4^x$", (-3, 2.5), purple_default, Fill(white));

