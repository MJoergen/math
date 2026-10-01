import systime;

real xmin =  -1.0;
real xmax =  11.0;
real xstep =  1.0;
real ymin = -50.0;
real ymax = 600.0;
real ystep = 50.0;

koord("$x$", xmin, xmax, xstep,
      "$y$", ymin, ymax, ystep,
      gitter = true);

real f1(real x)
{
    return 270*exp(log(1.07)*x);
}

pair p0  = ( 0, f1(0));
pair p10 = (10, f1(10));

draw(graph(f1, -1.0, 11.0), blue_default);

dot(p0);
dot(p10);



