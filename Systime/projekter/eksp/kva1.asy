import systime;

real xmin = -1.0;
real xmax = 5.0;
real xstep = 1.0;
real ymin = -5.0;
real ymax = 25;
real ystep = 5.0;

ternet("$x$", xmin, xmax, xstep,
       "$y$", ymin, ymax, ystep);

pair pc = (4.5826, 21);
pair pd = (4.5826, 0);

real f1(real x)
{
    return x^2.0;
}

real f3(real x)
{
    return 21;
}

draw(graph(f1, 0, xmax), blue_default);
draw(graph(f3, xmin, xmax), yellow_default);

label("$y=x^2$",  (2.0, 8), blue_default, filltype=Fill(white));
label("$y=21$",  (1.5, 19), yellow_default, filltype=Fill(white));

dot(pc);
draw(pc--pd, Dotted);

