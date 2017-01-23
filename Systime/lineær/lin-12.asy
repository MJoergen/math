import "../systime" as systime;

real xmin =  -2.0;
real xmax =  12.0;
real xstep =  2.0;
real ymin =  70.0;
real ymax = 160.0;
real ystep = 10.0;

koord("{\aa}r", xmin, xmax, xstep,
      "cm", ymin, ymax, ystep,
      gitter = true);

real f1(real x)
{
    return 6.53*x+78.2;
}

dot(( 2,  89.2));
dot(( 3,  98.3));
dot(( 4, 104.9));
dot(( 5, 112.0));
dot(( 6, 118.1));
dot(( 7, 123.4));
dot(( 8, 131.3));
dot(( 9, 136.4));
dot((10, 142.5));

draw(graph(f1, 1, 14.5), blue_default);

shipout(scale(5)*bbox(white));
