import systime;

real xmin = 3.0;
real xmax = 5.4;
real xstep = 0.2;
real ymin = 10;
real ymax = 25;
real ystep = 1;

koord("$x$", xmin, xmax, xstep,
      "$y$", ymin, ymax, ystep,
      ternet = true);

pair pa = (4, 16);
pair pb = (4.625, 21);
pair pc = (4.5826, 21);

real f1(real x)
{
    return x^2.0;
}

real f2(real x)
{
    return 8*x-16;
}

real f3(real x)
{
    return 21;
}

draw(graph(f1, 3.17, 5.0), blue_default);
draw(graph(f2, 3.25, 5.125), purple_default);
draw(graph(f3, xmin, xmax), yellow_default);

label("$y=x^2$",  (4.5, 23.5), blue_default, filltype=Fill(white));
label("$y=8x-16$",  (4.9, 19), purple_default, filltype=Fill(white));
label("$y=21$",  (3.5, 20), yellow_default, filltype=Fill(white));

dot(pa);
dot(pb);
dot(pc);

