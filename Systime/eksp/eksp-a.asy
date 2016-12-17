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

label("$x$", ( 5,    -0.6), align=SW);
label("$y$", (-0.25, 24),   align=SW);

ticks xticks = RightTicks(scale(0.6)*Label(align=right), new real[]{-4, -3, -2, -1, 1, 2, 3, 4}, Size=2);
ticks yticks = LeftTicks(scale(0.6)*Label(align=left), new real[]{-2, 2, 4, 6, 8, 10, 12, 14, 16, 18, 20, 22}, Size=2);

xaxis(xticks, Arrow(HookHead), xmin=-5, xmax=5);
yaxis(yticks, Arrow(HookHead), ymin=-3, ymax=24);

xequals(-4, dotted);
xequals(-3, dotted);
xequals(-2, dotted);
xequals(-1, dotted);
xequals(1, dotted);
xequals(2, dotted);
xequals(3, dotted);
xequals(4, dotted);

yequals(-2, dotted);
yequals(2, dotted);
yequals(4, dotted);
yequals(6, dotted);
yequals(8, dotted);
yequals(10, dotted);
yequals(12, dotted);
yequals(14, dotted);
yequals(16, dotted);
yequals(18, dotted);
yequals(20, dotted);
yequals(22, dotted);

real f1(real x)
{
    return exp(log(1.1)*x);
}

real f2(real x)
{
    return exp(log(1.4)*x);
}

real f3(real x)
{
    return exp(log(2.0)*x);
}

real f4(real x)
{
    return exp(log(0.9)*x);
}

real f5(real x)
{
    return exp(log(0.7)*x);
}

real f6(real x)
{
    return exp(log(0.5)*x);
}

draw(graph(f2, -4.5, 4.5), blue_default);
draw(graph(f3, -4.5, 4.5), purple_default);

draw(graph(f5, -4.5, 4.5), yellow_default);
draw(graph(f6, -4.5, 4.5), green_default);

label("$a=0,\!5$", (-2.5, 16), green_default, filltype=Fill(white));
label("$a=0,\!7$", (-4, 1.5), yellow_default, filltype=Fill(white));
label("$a=1,\!4$", (4, 1.5), blue_default, filltype=Fill(white));
label("$a=2,\!0$", (2.5, 16), purple_default, filltype=Fill(white));

