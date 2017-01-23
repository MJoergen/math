import "../systime" as systime;

real xmin  = -20.0;
real xmax  =  120.0;
real xstep =  10.0;
real ymin  = -40.0;
real ymax  = 240.0;
real ystep =  20.0;

koord("\scriptsize{C}", xmin, xmax, xstep,
      "\scriptsize{F}",  ymin, ymax, ystep,
      gitter = true);

real f1(real x)
{
    return 32.0 + 1.8*x;
}

draw(graph(f1, -10, 110), blue_default);

pair pa = (100, 212);
pair pb = (37, 98.6);

dot(pa);
dot(pb);

label("$y=32+1,8\,x$", (60, 40), blue_default*0.5 + black*0.5 , filltype=Fill(white));

shipout(scale(5)*bbox(white));
