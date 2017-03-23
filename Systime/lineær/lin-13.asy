import "../systime" as systime;

real xmin =  -4.0;
real xmax =   4.0;
real xstep =  1.0;
real ymin =  -3.0;
real ymax =   5.0;
real ystep =  1.0;

koord("$x$", xmin, xmax, xstep,
      "$y$", ymin, ymax, ystep,
      gitter = true);

// 2x+3y=4
real f1(real x)
{
    return (4-2*x)/3.0;
}

// -3x+4y=7
real f2(real x)
{
    return (7+3*x)/4.0;
}

draw(graph(f1, -4, 4), blue_default);
draw(graph(f2, -4, 4), purple_default);

pair pa = (-5/17.0, 26/17.0);
dot(pa);

label("$2x+3y=4$", (-2, 4.5), blue_default);
label("$-3x+4y=7$", (-2, -1.5), purple_default);

shipout(scale(5)*bbox(white));
