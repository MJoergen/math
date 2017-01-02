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

void koord(string xlabel, real xmin, real xmax, real xstep,
            string ylabel, real ymin, real ymax, real ystep,
            bool gitter = false)
{
    int xsteps = round((xmax - xmin)/xstep);
    int ysteps = round((ymax - ymin)/ystep);

    real[] xpoints;
    real[] ypoints;

    for (real x=xmin+xstep; x < xmax-1e-6; x += xstep)
    {
        if (abs(x) >= xstep*1e-6)
        {
            xpoints.push(x);
        }
    }

    for (real y=ymin+ystep; y < ymax-1e-6; y += ystep)
    {
        if (abs(y) >= ystep*1e-6)
        {
            ypoints.push(y);
        }
    }

    real xequals = xmin;
    real yequals = ymin;
    
    if (xmin * xmax < 0.0)
    {
        xequals = 0.0;
    }

    if (ymin * ymax < 0.0)
    {
        yequals = 0.0;
    }

    ticks xticks = RightTicks(scale(0.6)*Label(align=right), xpoints, Size=2);
    ticks yticks = LeftTicks(scale(0.6)*Label(align=left), ypoints, Size=2);

    xaxis(YEquals(yequals), xticks, Arrow(HookHead), xmin=xmin, xmax=xmax);
    yaxis(XEquals(xequals), yticks, Arrow(HookHead), ymin=ymin, ymax=ymax);

    label(xlabel, ( xmax,    yequals - (ymax-ymin)/40), align=SW);
    label(ylabel, (xequals - (xmax-xmin)/40, ymax),   align=SW);

    if (gitter)
    {
        for (int i=0; i<=xsteps; ++i)
        {
            xequals(xmin + xstep*i, dotted);
        }

        for (int i=0; i<=ysteps; ++i)
        {
            yequals(ymin + ystep*i, dotted);
        }
    }

} // end of koord

