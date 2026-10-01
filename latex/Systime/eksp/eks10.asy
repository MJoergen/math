import systime;

real xmin =  -1.0;
real xmax =  11.0;
real xstep =  1.0;
real ymin = -2.0;
real ymax = 30.0;
real ystep = 2.0;

koord("$x$", xmin, xmax, xstep,
      "$y$", ymin, ymax, ystep,
      gitter = true);

real f1(real x)
{
    return 9*exp(log(1.1)*x);
}

pair pa = ( 3,    f1(3));
pair pb = (10.27, f1(10.27));

draw(graph(f1, -1.0, 11.0), blue_default);

dot(pa);
dot(pb);



