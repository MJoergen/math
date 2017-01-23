import "../systime" as systime;

real xmin  = -10.0;
real xmax  =  110.0;
real xstep =  10.0;
real ymin  = -20.0;
real ymax  = 240.0;
real ystep =  20.0;

koord("\scriptsize{min.}", xmin, xmax, xstep,
      "\scriptsize{kr.}",  ymin, ymax, ystep,
      gitter = true);

real f1(real x)
{
    return 32.0 + 1.8*x;
}

draw(graph(f1, 0, 100), blue_default);

label("$y=32+1,8\,x$", (13, 7), blue_default*0.5 + black*0.5 , filltype=Fill(white));

shipout(scale(5)*bbox(white));
