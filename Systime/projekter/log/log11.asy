import systime;

real xmin = 0.0;
real xmax = 2.0;
real xstep = 0.2;
real ymin = -1.0;
real ymax = 1.0;
real ystep = 0.2;

koord("$x$", xmin, xmax, xstep,
      "$y$", ymin, ymax, ystep,
      gitter = true);

pair pc = (1, 0);

real f0(real x)
{
    return log(x) / log(10);
}

real f1(real x)
{
    return 0.4343*(x-1);
}

draw(graph(f0, 0.1, xmax), blue_default);
draw(graph(f1, xmin, xmax), yellow_default);

label("$f(x)=\log x$",  (0.8, -0.5), blue_default, filltype=Fill(white));
label("$y=0,4343\cdot(x-1)$",  (1.0, 0.4), yellow_default, filltype=Fill(white));

dot(pc);

