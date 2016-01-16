if(!settings.multipleView) settings.batchView=false;
settings.tex="pdflatex";
defaultfilename="side3371fig";
if(settings.render < 0) settings.render=4;
settings.outformat="";
settings.inlineimage=true;
settings.embed=true;
settings.toolbar=false;
viewportmargin=(2,2);

size(0,200);

real r = sqrt(50.0);
real g = 5.0;
real d = r + 1.0;
real c = d - 6.0;
real f = d + 4.0;
real e = g + 2.0;

pair po = (  r, 0.0);
pair pa = (0.0, 0.0);
pair pb = (2*r, 0.0);
pair pc = (  c, g);
pair pd = (  d, g);
pair pe = (  d, e);
pair pf = (  f, g);
pair pg = (  r, g);

dot(po);
dot(pa);
dot(pb);
dot(pc);
dot(pd);
dot(pe);
dot(pf);
dot(pg);

draw(pa..pb);
draw(po..pg);
draw(po..pd);
draw(po..pf);
draw(pc..pf);
draw(pd..pe);
draw(pc..pe);
draw(pe..pf);

void make_right(pair p0, pair p1, pair p2, real s)
{
    real d1 = length(p1-p0);
    real d2 = length(p2-p0);
    p1 = p0 + s*(p1-p0)/d1;
    p2 = p0 + s*(p2-p0)/d2;
    pair pm = p1-p0+p2;
    draw(pm..p1);
    draw(pm..p2);
} // end of make_right

draw(arc(po, r, 0.0, 180.0));
make_right(pg, pc, po, 0.3);
make_right(po, pg, pa, 0.3);
make_right(pd, pc, pe, 0.3);

label("\mbox{\footnotesize O}", po, 3*NW);
label("\mbox{\footnotesize A}", pa, NW);
label("\mbox{\footnotesize B}", pb, NE);
label("\mbox{\footnotesize C}", pc, NW);
label("\mbox{\footnotesize D}", pd, SE);
label("\mbox{\footnotesize E}", pe, N);
label("\mbox{\footnotesize F}", pf, NE);
label("\mbox{\footnotesize G}", pg, N);


