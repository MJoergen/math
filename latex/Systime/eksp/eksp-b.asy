import systime;

real xmin = -5.0;
real xmax =  5.0;
real xstep = 1.0;
real ymin = -1.0;
real ymax =  9;
real ystep = 1.0;

koord("$x$", xmin, xmax, xstep,
      "$y$", ymin, ymax, ystep,
      gitter = true);

real f1(real x)
{
    return 4.7*exp(log(0.91)*x);
}

real f2(real x)
{
    return 3.1*exp(log(1.4)*x);
}

draw(graph(f1, -4.5, 4.5), blue_default);
draw(graph(f2, -4.5, 3), purple_default);

label("$y=4,\!7\cdot 0,\!91^x$", (-3, 4.5), blue_default, Fill(white));
label("$y=3,\!1\cdot 1,\!4^x$", (-3, 2.5), purple_default, Fill(white));

