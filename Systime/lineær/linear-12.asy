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

size(7cm, 7cm, keepAspect=false);

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

ticks xticks = RightTicks(scale(0.6)*Label(align=right), new real[]{2, 4, 6, 8, 10, 12}, Size=2);
ticks yticks = LeftTicks(scale(0.6)*Label(align=left), new real[]{90, 100, 110, 120, 130, 140, 150, 160}, Size=2);

xaxis(YEquals(80), xticks, Arrow(HookHead), xmin=-2.5, xmax=14.5);
yaxis(yticks, Arrow(HookHead), ymin=70, ymax=170);

xequals(2, dotted);
xequals(4, dotted);
xequals(6, dotted);
xequals(8, dotted);
xequals(10, dotted);
xequals(12, dotted);
xequals(14, dotted);

yequals(90, dotted);
yequals(100, dotted);
yequals(110, dotted);
yequals(120, dotted);
yequals(130, dotted);
yequals(140, dotted);
yequals(150, dotted);
yequals(160, dotted);

label("{\aa}r", (14, 78), align=SW, filltype=Fill(white));
label("cm", (-0.5, 170), align=SW, filltype=Fill(white));

real f1(real x)
{
    return 6.17*x+80.19;
}

dot(( 2,  89.2));
dot(( 3,  98.3));
dot(( 4, 104.9));
dot(( 5, 112.0));
dot(( 6, 118.1));
dot(( 7, 123.4));
dot(( 8, 131.3));
dot(( 9, 136.4));
dot((10, 142.5));
dot((11, 151.1));
dot((12, 155.4));
dot((13, 159.8));
dot((14, 161.5));

draw(graph(f1, 1, 14.5), blue_default);

