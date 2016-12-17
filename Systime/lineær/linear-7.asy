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
    return 0.5*x+1.5;
}

pair p1   = (1.0, f1(1.0));
pair p1x  = (p1.x, 0.0);
pair p1y  = (0.0, p1.y);
pair p2   = (4.0, f1(4.0));
pair p2x  = (p2.x, 0.0);
pair p2y  = (0.0, p2.y);

draw(graph(f1,  -1, 5), blue_default);
draw(p1x..p1, dotted);
draw(p1y..p1, dotted);
draw(p2x..p2, dotted);
draw(p2y..p2, dotted);
draw(p1..p2x+p1y);
draw(p2..p2x+p1y);

dot(p1);
dot(p2);

label("$y=ax+b$",  ( 4, f1(4)), N*5);
label("$x$",   p1x, S);
label("$x+1$", p2x, S);
label("$y_1$", p1y, W);
label("$y_2$", p2y, W);
label("$1$",   (p1+p2x+p1y)/2, S);
label("$a$",   (p2+p2x+p1y)/2, E);


xaxis(arrow=Arrow(HookHead));
yaxis(arrow=Arrow(HookHead));

fixedscaling((-1, -1), (5, 5));
