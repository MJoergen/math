import "../projekter/eksp/systime" as systime;

real xmin = -2.0;
real xmax =  5.0;
real xstep = 1.0;
real ymin = -6.0;
real ymax =  7.0;
real ystep = 1.0;

koord("\scriptsize{$x$}", xmin, xmax, xstep,
      "\scriptsize{$y$}", ymin, ymax, ystep,
      gitter = true);

real f1(real x)
{
    return 3*x-5;
}

pair p0 = (0.0, f1(0.0));
pair p1 = (1.0, f1(1.0));
pair p2 = (2.0, f1(2.0));
pair p3 = (3.0, f1(3.0));

draw(graph(f1,  0, 4), blue_default);
dot(p0);
dot(p1);
dot(p2);
dot(p3);

label("$y=3x-5$",  ( 0.5, f1( 0.5)), 2E, blue_default*0.5, filltype=Fill(white));
label("$(0, -5)$", p0, 2E, black, filltype=Fill(white));
label("$(1, -2)$", p1, 2E, black, filltype=Fill(white));
label("$(2,  1)$", p2, 2E, black, filltype=Fill(white));
label("$(3,  4)$", p3, 2E, black, filltype=Fill(white));

fixedscaling((-0.5, -6), (4, 6));


