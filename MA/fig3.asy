if(!settings.multipleView) settings.batchView=false;
settings.tex="pdflatex";
defaultfilename="fig3";
if(settings.render < 0) settings.render=4;
settings.outformat="";
settings.inlineimage=true;
settings.embed=true;
settings.toolbar=false;
viewportmargin=(2,2);

size(0,200);

real r = 0.35;
real q = 0.2;
real a = 0.45;

real h = sqrt(r*r - (r-q)*(r-q));
pair pa = ( 0.5*q, a);
pair pb = (   2*r, 0.0);
pair pc = (   0.0, 0.0);
pair ps = pa + pb;
pair pm = 0.5*ps;
pair pq = ( q, 0.0);
pair po = ( r, 0.0);
pair pn = ( q, h);


dot(pa);
dot(pb);
dot(pc);
dot(ps);
dot(pm);
dot(pq);
dot(pn);

draw(pa..pb);
draw(pb..pc);
draw(pc..pa);
draw(pa..pq);

draw(pc..ps, dashed);
draw(circle(po, r));

label("\mbox{\footnotesize A}", pa, SW);
label("\mbox{\footnotesize B}", pb, SE);
label("\mbox{\footnotesize C}", pc, SW);
label("\mbox{\footnotesize S}", ps, SE);
label("\mbox{\footnotesize M}", pm, N);
label("\mbox{\footnotesize Q}", pq, S);
label("\mbox{\footnotesize N}", pn, S);

draw(pa..pn, dotted);
draw(pb..pn, dotted);
draw(ps..pn, dotted);

