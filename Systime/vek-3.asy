import "systime" as systime;

real v = 0.6;

pair po = (0, 0);
pair px = (1, 0);
pair pv = (cos(v), sin(v));
pair pa = 1.5*pv;

vinkelbue(po, px, pv, 0.4, yellow_thin);

draw(po--pv, black_default, systime_arrow);
draw(po--pa, black_thin, systime_arrow);

label("$\vec{e}$", pv/2, NW);
label("$\vec{a}$", pa*0.9, NW);
label("$P$", pv, 2*E);

dot(pv);

xaxis(YEquals(0), systime_arrow, xmin=-1.5, xmax=1.5);
yaxis(XEquals(0), systime_arrow, ymin=-1.5, ymax=1.5);

draw(arc(po, 1, -20, 120));

shipout(scale(5)*bbox(white));

