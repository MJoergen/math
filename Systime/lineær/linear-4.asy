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
    return 20.0 + 0.5*x;
}

draw(graph(f1, 0, 20), blue_default);

label("\tiny{min.}", (20,   -0.75), align=SW);
label("\tiny{kr.}",  (-0.5, 30),    align=SW);

ticks xticks = RightTicks(scale(0.6)*Label(align=right), new real[]{5, 10, 15}, Size=2);
ticks yticks = LeftTicks(scale(0.6)*Label(align=left), new real[]{5, 10, 15, 20, 25}, Size=2);

xaxis(xticks, Arrow(HookHead), xmin=0);
yaxis(yticks, Arrow(HookHead), ymin=0);

xequals(5, dotted);
xequals(10, dotted);
xequals(15, dotted);
xequals(20, dotted);

yequals(5, dotted);
yequals(10, dotted);
yequals(15, dotted);
yequals(20, dotted);
yequals(25, dotted);
yequals(30, dotted);

label("$y=20+0,\!5\,x$", (13, 22), blue_default, filltype=Fill(white));

