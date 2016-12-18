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
texpreamble("\DeclareMathSymbol{,}{\mathord}{letters}{\"3B}");

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

label("$x$", ( 4,    -150), align=SW);
label("$y$", (-0.1, 6000),   align=SW);

ticks xticks = RightTicks(scale(0.6)*Label(align=right), new real[]{1, 2, 3}, Size=2);
ticks yticks = LeftTicks(scale(0.6)*Label(align=left), new real[]{1000, 2000, 3000, 4000, 5000}, Size=2);

xaxis(xticks, Arrow(HookHead), xmin=-1, xmax=4);
yaxis(yticks, Arrow(HookHead), ymin=0, ymax=6000);

xequals(-1, dotted);
xequals(1, dotted);
xequals(2, dotted);
xequals(3, dotted);
xequals(4, dotted);

yequals(1000, dotted);
yequals(2000, dotted);
yequals(3000, dotted);
yequals(4000, dotted);
yequals(5000, dotted);
yequals(6000, dotted);

real f1(real x)
{
    return 2154.74*exp(log(1.35214)*x);
}

pair p0 = (0.0, 2180);
pair p1 = (1.0, 2955);
pair p2 = (2.0, 3698);
pair p3 = (3.0, 5530);

dot(p0);
dot(p1);
dot(p2);
dot(p3);

