import "systime" as systime;

pair va = (-2, 3);
pair vb = (5, 1);
pair vc = va + vb;

pair po = (0, 0);
pair pa = po + va;
pair pb = po + vb;
pair pc = po + vc;

draw(po..pa, black_default, systime_arrow);
draw(po..pb, black_default, systime_arrow);
draw(po..pc, black_default, systime_arrow);
draw(pa..pc, grey_thin);
draw(pb..pc, grey_thin);

dot(po);
dot(pa);
dot(pb);
dot(pc);

label("$\vec{a}$", po + va/2, SW);
label("$\vec{b}$", po + vb/2, SE);
label("$\vec{a}+\vec{b}$", po + vc/2, SE);

shipout(scale(5)*bbox(white));

