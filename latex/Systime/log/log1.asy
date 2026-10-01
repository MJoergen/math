import systime;

real xmin = -2.0;
real xmax = 13.0;
real xstep = 1.0;
real ymin = -2.0;
real ymax = 13;
real ystep = 1.0;

koord("$x$", xmin, xmax, xstep,
      "$y$", ymin, ymax, ystep,
      gitter = true);

real f1(real x)
{
    return log(x)/log(10.0);
}

real f2(real x)
{
    return x;
}

real f3(real x)
{
    return exp(x*log(10.0));
}

draw(graph(f1, f3(xmin), xmax), blue_default);
draw(graph(f2, xmin, xmax), dashed);
draw(graph(f3, xmin, f1(ymax)), yellow_default);

label("$g(x)=\log x$",  (7.0, 2.0), blue_default, filltype=Fill(white));
label("$f(x)=10^x$",  (3.5, 8), yellow_default, filltype=Fill(white));

pair pa = (10.0, 1.0);

dot(pa);

draw((10,0) .. pa, Dotted);
draw((0,1) .. pa, Dotted);
