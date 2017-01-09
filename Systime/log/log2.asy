import systime;

real xmin = -2.0;
real xmax =  3.0;
real xstep = 1.0;
real ymin = -2.0;
real ymax =  3;
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

label("$g(x)=\log x$",  (2.0, 0.7), blue_default, filltype=Fill(white));
label("$f(x)=10^x$",  (1.2, 2.2), yellow_default, filltype=Fill(white));

