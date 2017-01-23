import "../systime" as systime;

real xmin  = -2.0;
real xmax  =  4.0;
real xstep =  1.0;
real ymin  = -5.0;
real ymax  =  5.0;
real ystep =  1.0;

koord("\scriptsize{min.}", xmin, xmax, xstep,
      "\scriptsize{kr.}",  ymin, ymax, ystep,
      gitter = true);

real f1(real x)
{
    return 1.0 + 2.0*x;
}

draw(graph(f1, -1, 3), blue_default);

pair pa = (1, 1);
pair pb = (2, 3);

dot(pa);
dot(pb);

draw(pa..(2,1), Dotted);
draw(pb..(2,1), Dotted);

label("$y=2x+1$", (3, 2), blue_default*0.5 + black*0.5 , filltype=Fill(white));

shipout(scale(5)*bbox(white));
