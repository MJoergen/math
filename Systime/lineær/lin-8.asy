import "../systime" as systime;

real xmin = -2.0;
real xmax = 5.0;
real xstep = 1.0;
real ymin = -1.0;
real ymax = 6.0;
real ystep = 1.0;

koord("$x$", xmin, xmax, xstep,
      "$y$", ymin, ymax, ystep,
      gitter = true);

real f1(real x)
{
    return 0.4*(x-4.0)+5.0;
}

pair F1(real x)
{
    return (x, f1(x));
}

pair pa = F1(-1.0);
pair pb = F1(4.0);

label("A", pa, NW);
label("B", pb, NW);
label("$(-1, 3)$", pa, 3S, filltype=Fill(white));
label("$(4, 5)$", pb, 2S, filltype=Fill(white));

draw(graph(f1, -2, 5), blue_default);

dot(pa);
dot(pb);

shipout(scale(5)*bbox(white));
