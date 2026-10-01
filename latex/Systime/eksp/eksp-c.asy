import systime;

real xmin = -3.0;
real xmax =  3.0;
real xstep = 1.0;
real ymin = -1.0;
real ymax =  6;
real ystep = 1.0;

koord("$x$", xmin, xmax, xstep,
      "$y$", ymin, ymax, ystep,
      gitter = true);

real f1(real x)
{
    return 2*exp(log(0.7)*x);
}

real f2(real x)
{
    return 2*exp(log(1.4)*x);
}

pair F1(real x) {return (x,f1(x));}
pair F2(real x) {return (x,f2(x));}

draw(graph(f1, -3, 3), blue_default);
draw(graph(f2, -3, 3), purple_default);

label("$a<1$", F1(-2.0), NE, blue_default, Fill(white));
label("$a>1$", F2(2.0), NW, purple_default, Fill(white));

