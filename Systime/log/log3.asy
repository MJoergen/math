import systime;

real xmin = -2.0;
real xmax =  7.0;
real xstep = 1.0;
real ymin = -2.0;
real ymax =  7;
real ystep = 1.0;

koord("$x$", xmin, xmax, xstep,
      "$y$", ymin, ymax, ystep,
      gitter = true);

real f1(real x)
{
    return log(x);
}

real f2(real x)
{
    return x;
}

real f3(real x)
{
    return exp(x);
}

draw(graph(f1, f3(xmin), xmax), blue_default);
draw(graph(f2, xmin, xmax), dashed);
draw(graph(f3, xmin, f1(ymax)), yellow_default);

label("$g(x)=\ln x$",  (5.5, 2.3), blue_default, filltype=Fill(white));
label("$f(x)={\rm e}^x$",  (3.2, 6), yellow_default, filltype=Fill(white));

pair pa = (exp(1.0), 1.0);

dot(pa);

draw((exp(1.0), 0) .. pa, Dotted);
draw((0, 1) .. pa, Dotted);

label(scale(0.6)*"e", (exp(1.0),0), 2S);
