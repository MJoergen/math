import "../projekter/eksp/systime" as systime;

real xmin = -1.0;
real xmax = 5.0;
real xstep = 1.0;
real ymin = -1.0;
real ymax = 9.0;
real ystep = 1.0;

koord("$x$", xmin, xmax, xstep,
      "$y$", ymin, ymax, ystep,
      gitter = true);

real f1(real x)
{
    return 1.6*x+1;
}

pair p0 = (1,2);
pair p1 = (2,5);
pair p2 = (3,6);
pair p3 = (4,7);

dot(p0);
dot(p1);
dot(p2);
dot(p3);

draw(graph(f1, -0.5, 5), blue_default);

