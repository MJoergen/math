import "../systime" as systime;

real xmin =   0.0;
real xmax = 300.0;
real xstep = 50.0;
real ymin =   0.0;
real ymax = 600.0;
real ystep = 50.0;

koord("$x$", xmin, xmax, xstep,
      "$y$", ymin, ymax, ystep,
      gitter = true);

real f1(real x)
{
    return 1.58*x+146;
}

pair p1 = ( 50, 225);
pair p2 = (100, 305);
pair p3 = (150, 380);
pair p4 = (200, 465);
pair p5 = (250, 540);

draw(graph(f1, 0, 270), blue_default);

dot(p1);
dot(p2);
dot(p3);
dot(p4);
dot(p5);

label("$y=1,58x+146$", (200, 300), blue_default, filltype=Fill(white));

shipout(scale(5)*bbox(white));

