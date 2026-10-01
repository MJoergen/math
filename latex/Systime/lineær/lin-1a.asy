import "../systime" as systime;

real xmin  =   0.0;
real xmax  =  120.0;
real xstep =  10.0;
real ymin  =   0.0;
real ymax  = 240.0;
real ystep =  20.0;

koord("\scriptsize{$x$}", xmin, xmax, xstep,
      "\scriptsize{$y$}",  ymin, ymax, ystep,
      gitter = true);

real f1(real x)
{
    return 32.0 + 1.8*x;
}

draw(graph(f1, -3 , 115), blue_default);

pair pa = (100, 212);
pair pb = (37, 98.6);
pair pc = (0, 32);

dot(pa);
dot(pb);
dot(pc);

label("$y=1,8\cdot x+32$", (60, 40), blue_default*0.5 + black*0.5 , filltype=Fill(white));

shipout(scale(5)*bbox(white));
