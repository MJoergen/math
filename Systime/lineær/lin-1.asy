import "../systime" as systime;

real xmin  =  0.0;
real xmax  = 20.0;
real xstep =  5.0;
real ymin  =  0.0;
real ymax  = 20.0;
real ystep =  5.0;

koord("\scriptsize{min.}", xmin, xmax, xstep,
      "\scriptsize{kr.}",  ymin, ymax, ystep,
      gitter = true);

real f1(real x)
{
    return 5.0 + 0.5*x;
}

draw(graph(f1, 0, 20), blue_default);

label("$y=0,50\cdot x + 5$", (13, 7), blue_default*0.5 + black*0.5 , filltype=Fill(white));

shipout(scale(5)*bbox(white));
