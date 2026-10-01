import "../systime" as systime;

real xmin  = -5.0;
real xmax  =  5.0;
real xstep =  1.0;
real ymin  = -4.0;
real ymax  =  4.0;
real ystep =  1.0;

koord("\scriptsize{x}", xmin, xmax, xstep,
      "\scriptsize{y}",  ymin, ymax, ystep,
      gitter = true);

real f1(real x)
{
    return 0.5*x+2;
}

real f2(real x)
{
    return 0.5*x-1;
}

draw(graph(f1, -5, 4), blue_default);
draw(graph(f2, -5, 5), purple_default);

draw((2,-4)..(2,4), yellow_default);

label("$a=0,5$", (-2, 2), blue_default , filltype=Fill(white));
label("$a=0,5$", (-3, -1.5), purple_default , filltype=Fill(white));

shipout(scale(5)*bbox(white));
