import "../systime" as systime;

real xmin = -8.0;
real xmax = 10.0;
real xstep = 2.0;
real ymin = -6.0;
real ymax = 10.0;
real ystep = 2.0;

koord("\scriptsize{$x$}", xmin, xmax, xstep,
      "\scriptsize{$y$}", ymin, ymax, ystep,
      gitter = true);


real f1(real x)
{
    return 3*x-5;
}

real f2(real x)
{
    return -2*x+1;
}

real f3(real x)
{
    return 4-x;
}

real f4(real x)
{
    return 3*x;
}

draw(graph(f1,  0, 5), blue_default);
draw(graph(f2, -4, 3), purple_default);
draw(graph(f3, -5, 9), yellow_default);
draw(graph(f4, -2, 3), green_default);

label("$y=3x-5$",  ( 4.0, f1( 4.0)), E,  blue_default*0.5,   filltype=Fill(white));
label("$y=-2x+1$", (-1.5, f2(-1.5)), SW, purple_default*0.5, filltype=Fill(white));
label("$y=4-x$",   ( 4.0, f3( 4.0)), NE, yellow_default*0.5, filltype=Fill(white));
label("$y=3x$",    (-1.0, f4(-1.0)), W,  green_default*0.5,  filltype=Fill(white));

