import "../systime" as systime;

real f1(real x)
{
    return 0.5*x+2;
}

pair F1(real x)
{
    return (x, f1(x));
}

pair pa  = (1.0, 2.5);
pair pb  = (4.0, 4.0);
pair pay = (0.0, 2.5);
pair pby = (0.0, 4.0);
pair pax = (1.0, 0.0);
pair pbx = (4.0, 0.0);

draw(pay..pa, Dotted);
draw(pby..pb, Dotted);
draw(pax..pa, Dotted);
draw(pbx..pb, Dotted);

label("\scriptsize{$y_1$}", pay, W);
label("\scriptsize{$y_2$}", pby, W);
label("\scriptsize{$x_1$}", pax, S);
label("\scriptsize{$x_2$}", pbx, S);

label("A", pa, NW);
label("B", pb, NW);
label("$(x_1,y_1)$", pa, SE);
label("$(x_2,y_2)$", pb, SE);

draw(graph(f1, -1, 5), blue_default);

dot(pa);
dot(pb);

xaxis("$x$", NoTicks, systime_arrow);
yaxis("$y$", NoTicks, systime_arrow);

