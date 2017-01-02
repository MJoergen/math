import systime;

real xmin = -1.0;
real xmax =  9.0;
real xstep = 1.0;
real ymin = -10;
real ymax = 10;
real ystep = 2.0;

koord("$x$", xmin, xmax, xstep,
      "$y$", ymin, ymax, ystep,
      ternet = true);

pair pa = (5.64575, 5);
pair pb = (0.35425, 5);
pair pc = (3, -2);

real f1(real x)
{
    return x^2 - 6*x + 7;
}

real f2(real x)
{
    return 5;
}

real f3(real x)
{
    return -2;
}

real f4(real x)
{
    return -5;
}

draw(graph(f1, -0.3, 6.3), blue_default);
draw(graph(f2, xmin, xmax), purple_default);
draw(graph(f3, xmin, xmax), yellow_default);
draw(graph(f4, xmin, xmax), green_default);

label("$y=x^2-6x+7$",  (3.5, 8), blue_default, filltype=Fill(white));
label("$y=5$",  (3.0, 4), purple_default, filltype=Fill(white));
label("$y=-2$",  (1.5, -3), yellow_default, filltype=Fill(white));
label("$y=-5$",  (5.5, -6), green_default, filltype=Fill(white));

dot(pa);
dot(pb);
dot(pc);

