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

real xmin = 3.0;
real xmax = 5.4;
real xstep = 0.2;
real ymin = 10;
real ymax = 25;
real ystep = 1;

int xsteps = round((xmax - xmin)/xstep);
int ysteps = round((ymax - ymin)/ystep);

label("$x$", ( xmax,    ymin - (ymax-ymin)/40), align=SW);
label("$y$", (xmin - (xmax-xmin)/40, ymax),   align=SW);

real xv(int n)
{
    return xmin + xstep*n;
}

real yv(int n)
{
    return ymin + ystep*n;
}

real[] xpoints = sequence(xv, xsteps);
real[] ypoints = sequence(yv, ysteps);

ticks xticks = RightTicks(scale(0.6)*Label(align=right), xpoints, Size=2);
ticks yticks = LeftTicks(scale(0.6)*Label(align=left), ypoints, Size=2);

xaxis(YEquals(ymin), xticks, Arrow(HookHead), xmin=xmin, xmax=xmax);
yaxis(XEquals(xmin), yticks, Arrow(HookHead), ymin=ymin, ymax=ymax);

for (int i=0; i<=xsteps; ++i)
{
    xequals(xmin + xstep*i, dotted);
}

for (int i=0; i<=ysteps; ++i)
{
    yequals(ymin + ystep*i, dotted);
}

pair pa = (4, 16);
pair pb = (4.625, 21);
pair pc = (4.5826, 21);

real f1(real x)
{
    return x^2.0;
}

real f2(real x)
{
    return 8*x-16;
}

real f3(real x)
{
    return 21;
}

draw(graph(f1, 3.17, 5.0), blue_default);
draw(graph(f2, 3.25, 5.125), purple_default);
draw(graph(f3, xmin, xmax), yellow_default);

label("$y=x^2$",  (4.5, 23.5), blue_default, filltype=Fill(white));
label("$y=8x-16$",  (4.9, 19), purple_default, filltype=Fill(white));
label("$y=21$",  (3.5, 20), yellow_default, filltype=Fill(white));

dot(pa);
dot(pb);
dot(pc);

