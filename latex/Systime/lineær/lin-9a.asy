import "../systime" as systime;

real xmin  =  0.0;
real xmax  = 20.0;
real xstep =  5.0;
real ymin  =  0.0;
real ymax  = 20.0;
real ystep =  5.0;

koord("\scriptsize{min.}", xmin, xmax, xstep,
      "\scriptsize{kr.}",  ymin, ymax, ystep,
      gitter = true);

real f1(real x)
{
    return 5.0 + 0.5*x;
}

real f2(real x)
{
    return 10.0 + 0.2*x;
}

draw(graph(f1, 0, 20), blue_default);
draw(graph(f2, 0, 20), purple_default);

label("$y=5+0,5\,x$", (13, 8), blue_default, filltype=Fill(white));
label("$y=10+0,2\,x$", (6, 13), purple_default, filltype=Fill(white));

shipout(scale(5)*bbox(white));
