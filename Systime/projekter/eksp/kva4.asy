import systime;

real xmin = -1.0;
real xmax =  7.0;
real xstep = 1.0;
real ymin = -2;
real ymax = 18;
real ystep = 2.0;

koord("$x$", xmin, xmax, xstep,
      "$y$", ymin, ymax, ystep,
      ternet = true);

pair pc = (3, 9);

real f1(real x)
{
    return x^2;
}

real f2(real x)
{
    return 6*x-9;
}


draw(graph(f1, -1, 4.2), blue_default);
draw(graph(f2, 1.2, 4.5), purple_default);

label("$f(x)=x^2$",  (2.0, 14), blue_default, filltype=Fill(white));
label("$y=6x-9$",  (4.0, 4), purple_default, filltype=Fill(white));

dot(pc);

