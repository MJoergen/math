import "../systime" as systime;

real xmin = -10.0;
real xmax =  60.0;
real xstep = 10.0;
real ymin = -10.0;
real ymax =  80.0;
real ystep = 10.0;

koord("\scriptsize{min}", xmin, xmax, xstep,
      "\scriptsize{kr}", ymin, ymax, ystep,
      gitter = true);

real f1(real x)
{
    return 1.5*x;
}

pair p0 = ( 5.0, f1( 5.0));
pair p1 = (15.0, f1(15.0));
pair p2 = (20.0, f1(20.0));
pair p3 = (28.0, f1(28.0));
pair p4 = (36.0, f1(36.0));
pair p5 = (44.0, f1(44.0));

draw(graph(f1, 0, 50), blue_default);
dot(p0);
dot(p1);
dot(p2);
dot(p3);
dot(p4);
dot(p5);

label("$y=1\frac{1}{2}x$",  ( 5, 65), E, filltype=Fill(white));
label("$(20, 30)$", p2, SE, filltype=Fill(white));
label("$(28, 42)$", p3, SE, filltype=Fill(white));
label("$(36, 54)$", p4, NW, filltype=Fill(white));
label("$(44, 66)$", p5, NW, filltype=Fill(white));
draw(p4..(44,54), Dotted);
draw(p5..(44,54), Dotted);
draw(p0..(15,7.5), Dotted);
draw(p1..(15,7.5), Dotted);

label("$10$", (p0+(15,7.5))/2, S, filltype=Fill(white));
label("$15$", (p1+(15,7.5))/2, E, filltype=Fill(white));

label("$8$", (p4+(44,54))/2, S, filltype=Fill(white));
label("$12$", (p5+(44,54))/2, E, filltype=Fill(white));

fixedscaling((-10, -10), (60, 80));

