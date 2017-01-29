import systime;

real xmin = -2.0;
real xmax =  5.0;
real xstep = 1.0;
real ymin = -1000.0;
real ymax =  7000;
real ystep = 1000.0;

koord("$x$", xmin, xmax, xstep,
      "$y$", ymin, ymax, ystep,
      gitter = true);

real f1(real x)
{
    return 2154.74*exp(log(1.35214)*x);
}

pair p1 = (0.0, 2180);
pair p2 = (1.0, 2955);
pair p3 = (2.0, 3698);
pair p4 = (3.0, 5530);

draw(graph(f1, 0, 3.8), blue_default);

dot(p1);
dot(p2);
dot(p3);
dot(p4);

label("$f(x) = 2155 \cdot 1,\!35^x$", (2.5, 2000), blue_default, Fill(white));

