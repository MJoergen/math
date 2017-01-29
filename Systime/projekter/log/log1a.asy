import systime;

real xmin = 0.7;
real xmax = 1.3;
real xstep = 0.1;
real ymin = -0.4;
real ymax = 0.4;
real ystep = 0.1;

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

draw(graph(f0, xmin, xmax), blue_default);
draw(graph(f1, xmin, xmax), yellow_default);

label("$f(x)=\log x$",  (0.9, -0.2), blue_default, filltype=Fill(white));
label("$y=0,4343\cdot(x-1)$",  (1.0, 0.15), yellow_default, filltype=Fill(white));

dot(pc);

