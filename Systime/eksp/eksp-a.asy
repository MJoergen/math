import systime;

real xmin = -5.0;
real xmax =  5.0;
real xstep = 1.0;
real ymin = -3.0;
real ymax = 24;
real ystep = 2.0;

koord("$x$", xmin, xmax, xstep,
      "$y$", ymin, ymax, ystep,
      gitter = true);

real f1(real x)
{
    return exp(log(1.1)*x);
}

real f2(real x)
{
    return exp(log(1.4)*x);
}

real f3(real x)
{
    return exp(log(2.0)*x);
}

real f4(real x)
{
    return exp(log(0.9)*x);
}

real f5(real x)
{
    return exp(log(0.7)*x);
}

real f6(real x)
{
    return exp(log(0.5)*x);
}

draw(graph(f2, -4.5, 4.5), blue_default);
draw(graph(f3, -4.5, 4.5), purple_default);

draw(graph(f5, -4.5, 4.5), yellow_default);
draw(graph(f6, -4.5, 4.5), green_default);

label("$a=0,\!5$", (-2.5, 16), green_default, filltype=Fill(white));
label("$a=0,\!7$", (-4, 1.5), yellow_default, filltype=Fill(white));
label("$a=1,\!4$", (4, 1.5), blue_default, filltype=Fill(white));
label("$a=2,\!0$", (2.5, 16), purple_default, filltype=Fill(white));

