import systime;

real xmin = -1.0;
real xmax =  6.0;
real xstep = 1.0;
real ymin = -10.0;
real ymax =  45;
real ystep = 10.0;

koord("$x$", xmin, xmax, xstep,
      "$y$", ymin, ymax, ystep,
      gitter = true);

real f1(real x)
{
    return 0.074074*exp(log(3.0)*x);
}

pair p1 = (3.0,  2.0);
pair p2 = (5.0, 18.0);

draw(graph(f1, 0, 5.8), blue_default);

label("$f(x) = \frac{2}{27}\cdot 3^x$", (3, 30), blue_default, Fill(white));
label("$(3,\,2)$", (2.7, 5), blue_default, Fill(white));
label("$(5,\,18)$", (5.3, 9.5), blue_default, Fill(white));

dot(p1);
dot(p2);

