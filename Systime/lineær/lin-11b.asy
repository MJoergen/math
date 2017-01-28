import "../systime" as systime;

real xmin = 0.0;
real xmax = 9.0;
real xstep = 1.0;
real ymin = 000.0;
real ymax = 1400.0;
real ystep = 100.0;

koord("$x$", xmin, xmax, xstep,
      "$y$", ymin, ymax, ystep,
      gitter = true);

real f1(real x)
{
    return -102.2*x+1115;
}

pair p1 = (0, 1261);
pair p2 = (1, 1012);
pair p3 = (2,  861);
pair p4 = (3,  671);
pair p5 = (4,  698);
pair p6 = (5,  548);
pair p7 = (6,  504);
pair p8 = (7,  417);
pair p9 = (9,  384);

dot(p1);
dot(p2);
dot(p3);
dot(p4);
dot(p5);
dot(p6);
dot(p7);
dot(p8);
dot(p9);

draw(graph(f1, 0, 9), blue_default);

label("$y=-102,2x+1115$", (4, 300), blue_default, filltype=Fill(white));

shipout(scale(5)*bbox(white));

