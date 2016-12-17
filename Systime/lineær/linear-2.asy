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

pair pa = (3.0, 1.0);
pair pb = (3.0, 6.0);

draw(pa..pb, blue_default);

dot(pa);
dot(pb);

label("A", pa, W);
label("B", pb, W);
label("$(x_1,y_1)$", pa, E);
label("$(x_2,y_2)$", pb, E);

xaxis("$x$", NoTicks, Arrow(HookHead));
yaxis("$y$", NoTicks, Arrow(HookHead));

