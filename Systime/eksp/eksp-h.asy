import systime;

real xmin = -1.0;
real xmax =  4.0;
real xstep = 1.0;
real ymin =  0.0;
real ymax = 6000;
real ystep = 1000.0;

koord("$x$", xmin, xmax, xstep,
      "$y$", ymin, ymax, ystep,
      gitter = true);

real f1(real x)
{
    return 2154.74*exp(log(1.35214)*x);
}

draw(graph(f1, 0.0, 3.4), blue_default);

label("$f(x)=2154,74\cdot1,35214^x$", (2, 1600), blue_default, filltype=Fill(white));

pair p0 = (0.0, 2180);
pair p1 = (1.0, 2955);
pair p2 = (2.0, 3698);
pair p3 = (3.0, 5530);

dot(p0);
dot(p1);
dot(p2);
dot(p3);

