//////////////////////////////////////////////////////////////////
// Begin preamble

size(7cm, 7cm, IgnoreAspect);
settings.outformat="pdf";

import graph;

texpreamble("\usepackage{MyriadPro}");
texpreamble("\usepackage{sfmath}");
texpreamble("\DeclareMathSymbol{,}{\mathord}{letters}{\"3B}");

pen blue_thin   = rgb("77afc3");
pen purple_thin = rgb("916fa2");
pen yellow_thin = rgb("f49e42");
pen green_thin  = rgb("6a9f7b");
pen grey_thin   = rgb("808080");
pen black_thin  = rgb("000000");
pen white_thin  = rgb("ffffff");

pen blue_default   = blue_thin   + 1.0;
pen purple_default = purple_thin + 1.0;
pen yellow_default = yellow_thin + 1.0;
pen green_default  = green_thin  + 1.0;
pen grey_default   = grey_thin   + 1.0;
pen black_default  = black_thin  + 1.0;

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
            if (abs(xmin + xstep*i) >= xstep*1e-6)
            {
                xequals(xmin + xstep*i, grey_thin + 0.2, ymin=ymin, ymax=ymax);
            }
        }

        for (int i=0; i<=ysteps; ++i)
        {
            if (abs(ymin + ystep*i) >= ystep*1e-6)
            {
                yequals(ymin + ystep*i, grey_thin + 0.2, xmin=xmin, xmax=xmax);
            }
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

void square(pair p1, pair p2)
{
    pair v1 = p2-p1;
    pair v2 = (-v1.y, v1.x);
    pair p3 = p1 + v2;
    pair p4 = p3 + v1;

    fill(p1--p2--p4--p3--cycle, grey_thin);
}

// Denne funktion laver et histogram
void bars(real[] x, real[] y1, real[] y2, real[] y3 = {}, real width = 0.6)
{
    real width = 0.6;

    pair prev_b;

    for (int i=0; i<y1.length; ++i)
    {
        pair a = (i, 0.0);
        pair b = (i+width, y1[i]);
        fill(box(a,b), blue_default);
        draw(box(a,b), defaultpen+0.3);

/*
        if (i>0)
        {
            pair c = (i, y1[i]);
            draw(prev_b -- c, grey_thin+0.3);
        }
*/

        label(scale(0.6)*("$"+(string)x[i]+"$"), a + (width/2, 0), align = S*1.5);

        a = (i, b.y);
        b = (i+width, a.y + y2[i]);
        fill(box(a,b), purple_default);
        draw(box(a,b), defaultpen+0.3);

        if (y3.length > 0) 
        {
            a = (i, b.y);
            b = (i+width, a.y + y3[i]);
            fill(box(a,b), yellow_default);
            draw(box(a,b), defaultpen+0.3);
        }

        prev_b = b;
    }

}

// Skalar-produkt
real dot(pair va, pair vb)
{
    return va.x*vb.x + va.y*vb.y;
}

// Projektion af va på vb
pair proj(pair va, pair vb)
{
    real t = dot(va, vb) / dot(vb, vb);
    pair res = (vb.x*t, vb.y*t);
    return res;
}

