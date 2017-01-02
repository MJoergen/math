import "../projekter/eksp/systime" as systime;

real f1(real x)
{
    return 0.5*x+1.5;
}

pair p1   = (1.0, f1(1.0));
pair p1x  = (p1.x, 0.0);
pair p1y  = (0.0, p1.y);
pair p2   = (4.0, f1(4.0));
pair p2x  = (p2.x, 0.0);
pair p2y  = (0.0, p2.y);

draw(graph(f1,  -1, 5), blue_default);
draw(p1x..p1, dotted);
draw(p1y..p1, dotted);
draw(p2x..p2, dotted);
draw(p2y..p2, dotted);
draw(p1..p2x+p1y);
draw(p2..p2x+p1y);

dot(p1);
dot(p2);

label("$y=ax+b$",  ( 4, f1(4)), N*5);
label("$x$",   p1x, S);
label("$x+1$", p2x, S);
label("$y_1$", p1y, W);
label("$y_2$", p2y, W);
label("$1$",   (p1+p2x+p1y)/2, S);
label("$a$",   (p2+p2x+p1y)/2, E);


xaxis(systime_arrow);
yaxis(systime_arrow);

fixedscaling((-1, -1), (5, 5));
