import "../systime" as systime;

real xmin  = -2.0;
real xmax  =  4.0;
real xstep =  1.0;
real ymin  = -4.0;
real ymax  =  5.0;
real ystep =  1.0;

koord("\scriptsize{x}", xmin, xmax, xstep,
      "\scriptsize{y}",  ymin, ymax, ystep,
      gitter = true);

real f1(real x)
{
    return -1.0 + 2.0*x;
}

draw(graph(f1, -1, 3), blue_default);

pair pa = (1, 1);
pair pb = (2, 3);

dot(pa);
dot(pb);

draw(pa..(2,1), Dotted);
draw(pb..(2,1), Dotted);

label("$y=2x-1$", (1, 3.5), blue_default*0.5 + black*0.5 , filltype=Fill(white));
label("1", (1.5, 1), S, black, filltype=Fill(white));
label("2", (2, 2), E, black, filltype=Fill(white));

shipout(scale(5)*bbox(white));
