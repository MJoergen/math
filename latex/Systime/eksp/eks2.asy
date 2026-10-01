import systime;

real xmin =  -5.0;
real xmax =  35.0;
real xstep =  5.0;
real ymin = -100.0;
real ymax = 900.0;
real ystep = 100.0;

koord("$x$", xmin, xmax, xstep,
      "$y$", ymin, ymax, ystep,
      gitter = true);

real f1(real x)
{
    return 700*exp(log(0.97)*x);
}

pair p0  = ( 0, f1(0));
pair p30 = (30, f1(30));

draw(graph(f1, -5.0, 35.0), blue_default);

dot(p0);
dot(p30);



