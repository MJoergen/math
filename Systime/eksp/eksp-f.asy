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

label("{\aa}r", ( 9,    -30), align=SW);
label("saldo", (-0.25, 1700),   align=SW);

ticks xticks = RightTicks(scale(0.6)*Label(align=right), new real[]{1, 2, 3, 4, 5, 6, 7, 8}, Size=2);
ticks yticks = LeftTicks(scale(0.6)*Label(align=left), new real[]{500, 1000, 1500}, Size=2);

xaxis(xticks, Arrow(HookHead), xmin=0, xmax=9);
yaxis(yticks, Arrow(HookHead), ymin=0, ymax=1700);

xequals(1, dotted);
xequals(2, dotted);
xequals(3, dotted);
xequals(4, dotted);
xequals(5, dotted);
xequals(6, dotted);
xequals(7, dotted);
xequals(8, dotted);

yequals(100, dotted);
yequals(200, dotted);
yequals(300, dotted);
yequals(400, dotted);
yequals(500, dotted);
yequals(600, dotted);
yequals(700, dotted);
yequals(800, dotted);
yequals(900, dotted);
yequals(1000, dotted);
yequals(1100, dotted);
yequals(1200, dotted);
yequals(1300, dotted);
yequals(1400, dotted);
yequals(1500, dotted);
yequals(1600, dotted);


real f1(real x)
{
    return 2154.74*exp(log(1.35214)*x);
}

pair p0 = (0.0, 1000);
pair p1 = (1.0, 1050);
pair p2 = (2.0, 1103);
pair p3 = (3.0, 1158);
pair p4 = (4.0, 1216);
pair p5 = (5.0, 1276);
pair p6 = (6.0, 1340);
pair p7 = (7.0, 1407);
pair p8 = (8.0, 1477);

dot(p0);
dot(p1);
dot(p2);
dot(p3);
dot(p4);
dot(p5);
dot(p6);
dot(p7);
dot(p8);

