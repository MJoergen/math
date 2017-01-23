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

arrowbar systime_arrow = Arrow(HookHead, size=3.5);

// Baggrundsfarven skal være helt hvid
texpreamble("\usepackage{color}");
texpreamble("\definecolor{background}{rgb}{1,1,1}");
texpreamble("\pagecolor{background}");

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

    xaxis(YEquals(yequals), xticks, systime_arrow, xmin=xmin, xmax=xmax);
    yaxis(XEquals(xequals), yticks, systime_arrow, ymin=ymin, ymax=ymax);

    label(xlabel, ( xmax,    yequals - (ymax-ymin)/40), align=SW);
    label(ylabel, (xequals - (xmax-xmin)/40, ymax),   align=SW);

    if (gitter)
    {
        for (int i=0; i<=xsteps; ++i)
        {
            xequals(xmin + xstep*i, linetype(new real[] {0,2}, scale=false)+0.6);
        }

        for (int i=0; i<=ysteps; ++i)
        {
            yequals(ymin + ystep*i, linetype(new real[] {0,2}, scale=false)+0.6);
        }
    }

} // end of koord


// Denne funktion tegner en ret vinkel i punktet p0,
// hvor p1 og p2 er vilkårlige punkter på de to vinkelben.
void retvinkel(pair p0, pair p1, pair p2, real size = 1.2, pen p = defaultpen)
{
    pair dir1 = (p1-p0) / length(p1-p0);
    pair dir2 = (p2-p0) / length(p2-p0);

    pair np1 = p0 + dir1 * size;
    pair np2 = p0 + dir2 * size;
    pair npm = p0 + (dir1+dir2) * size;
    draw(np1 -- npm -- np2, p);
} // end of retvinkel


// Denne funktion tegner en vinkelbue i punktet p0,
// hvor p1 og p2 er vilkårlige punkter på de to vinkelben.
void vinkelbue(pair p0, pair p1, pair p2, real size = 1.2, pen p = defaultpen)
{
    real dir1 = atan2(p1.y-p0.y, p1.x-p0.x)/2pi*360;
    real dir2 = atan2(p2.y-p0.y, p2.x-p0.x)/2pi*360;

    if (dir1 > dir2)
    {
        real temp = dir1;
        dir1 = dir2;
        dir2 = temp;
    }

    // Now dir1 < dir2
    if (dir2-dir1 > 180.0)
    {
        dir1 += 360.0;
    }

    path a = arc(p0, size, dir1, dir2);
    fill(a -- p0 -- cycle, p);
    draw(a);
} // end of vinkelbue

