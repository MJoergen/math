if(!settings.multipleView) settings.batchView=false;
settings.tex="pdflatex";
defaultfilename="fig1";
if(settings.render < 0) settings.render=4;
settings.outformat="";
settings.inlineimage=true;
settings.embed=true;
settings.toolbar=false;
viewportmargin=(2,2);

size(0,200);

pair pa = ( 0.0, 0.0);
pair pb = ( 0.0, 0.6);
pair pc = ( 0.8, 0.6);
pair pd = ( 0.8, 0.0);
pair pe = 0.64 * pc;
pair pf = 0.4375 * pd + pb;

dot(pa);
dot(pb);
dot(pc);
dot(pd);
dot(pe);
dot(pf);

draw(pa..pb);
draw(pb..pc);
draw(pc..pd);
draw(pd..pa);
draw(pa..pc);
draw(pd..pf);

label("\mbox{\footnotesize A}", pa, SW);
label("\mbox{\footnotesize B}", pb, NW);
label("\mbox{\footnotesize C}", pc, NE);
label("\mbox{\footnotesize D}", pd, SE);
label("\mbox{\footnotesize E}", pe, N);
label("\mbox{\footnotesize F}", pf, N);

