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

real xmin = -1.0;
real xmax = 5.0;
real xstep = 1.0;
real ymin = -5.0;
real ymax = 25;
real ystep = 5.0;

int xsteps = round((xmax - xmin)/xstep);
int ysteps = round((ymax - ymin)/ystep);

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

xaxis(YEquals(0), xticks, Arrow(HookHead), xmin=xmin, xmax=xmax);
yaxis(XEquals(0), yticks, Arrow(HookHead), ymin=ymin, ymax=ymax);

label("$x$", ( xmax,    0 - (ymax-ymin)/40), align=SW);
label("$y$", (0 - (xmax-xmin)/40, ymax),   align=SW);

for (int i=0; i<=xsteps; ++i)
{
    xequals(xmin + xstep*i, dotted);
}

for (int i=0; i<=ysteps; ++i)
{
    yequals(ymin + ystep*i, dotted);
}

pair pc = (4.5826, 21);
pair pd = (4.5826, 0);

real f1(real x)
{
    return x^2.0;
}

real f3(real x)
{
    return 21;
}

draw(graph(f1, 0, xmax), blue_default);
draw(graph(f3, xmin, xmax), yellow_default);

label("$y=x^2$",  (2.0, 8), blue_default, filltype=Fill(white));
label("$y=21$",  (1.5, 19), yellow_default, filltype=Fill(white));

dot(pc);
draw(pc--pd, Dotted);

