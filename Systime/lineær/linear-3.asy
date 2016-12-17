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
    return 0.4*(x-4.0)+5.0;
}

pair F1(real x)
{
    return (x, f1(x));
}

pair pa = F1(-1.0);
pair pb = F1(4.0);

label("A", pa, NW);
label("B", pb, NW);
label("$(-1, 3)$", pa, SE);
label("$(4, 5)$", pb, SE);

draw(graph(f1, -2, 5), blue_default);

dot(pa);
dot(pb);

xaxis("$x$", NoTicks, Arrow(HookHead));
yaxis("$y$", NoTicks, Arrow(HookHead));

