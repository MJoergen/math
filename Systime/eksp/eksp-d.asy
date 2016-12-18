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

label("$x$", ( 6,  -1.5), align=SW);
label("$y$", (-0.2, 45),   align=SW);

ticks xticks = RightTicks(scale(0.6)*Label(align=right), new real[]{-1, 1, 2, 3, 4, 5}, Size=2);
ticks yticks = LeftTicks(scale(0.6)*Label(align=left), new real[]{-10, 10, 20, 30, 40}, Size=2);

xaxis(xticks, Arrow(HookHead), xmin=-1, xmax=6);
yaxis(yticks, Arrow(HookHead), ymin=-10, ymax=45);

xequals(-1, dotted);
xequals(1, dotted);
xequals(2, dotted);
xequals(3, dotted);
xequals(4, dotted);
xequals(5, dotted);
xequals(6, dotted);

yequals(-10, dotted);
yequals(10, dotted);
yequals(20, dotted);
yequals(30, dotted);
yequals(40, dotted);

real f1(real x)
{
    return 0.074074*exp(log(3.0)*x);
}

pair p1 = (3.0,  2.0);
pair p2 = (5.0, 18.0);

draw(graph(f1, 0, 5.8), blue_default);

label("$f(x) = \frac{2}{27}\cdot 3^x$", (3, 30), blue_default, Fill(white));
label("$(3,\,2)$", (2.7, 5), blue_default, Fill(white));
label("$(5,\,18)$", (5.3, 9.5), blue_default, Fill(white));

dot(p1);
dot(p2);

