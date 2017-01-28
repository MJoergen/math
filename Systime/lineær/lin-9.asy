import "../systime" as systime;

real xmin = -4.0;
real xmax = 8.0;
real xstep = 2.0;
real ymin = -6.0;
real ymax = 8.0;
real ystep = 2.0;

koord("$x$", xmin, xmax, xstep,
      "$y$", ymin, ymax, ystep,
      gitter = true);

real f1(real x)
{
    return 0.5*x-2;
}

real f2(real x)
{
    return -3*x+5;
}

draw(graph(f1, -4, 8), blue_default);
draw(graph(f2, -1, 3.6), purple_default);

label("$y=0,5x-2$",  ( 5, f1(5)), N*6, blue_default*0.5, filltype=Fill(white));
label("$y=-3x+5$",   ( 3, f2(3)), E*2, purple_default*0.5, filltype=Fill(white));

shipout(scale(5)*bbox(white));
