import "systime" as systime;

// En kvadratisk hvid ramme rundt om, så vinkler forbliver rette.
//draw((0,0)--(6,0)--(6,6)--(6,0)--cycle, white_thin);

pair va = (1, 3);
pair vb = (3, 2);

pair vab = proj(va, vb); // Projektion af va på vb
pair vc = va - vab;

pair po = (0, 0);
pair pa = po + va;
pair pb = po + vb;
pair pc = po + vab;

draw(po..pa, black_default, systime_arrow);
draw(po..pb, black_default, systime_arrow);
draw(po..pc, black_default, systime_arrow);
draw(pc..pa, black_default, systime_arrow);

retvinkel(pc, pa, pb, 0.2);

dot(po);
dot(pa);
dot(pb);
dot(pc);

label("$\vec{a}$",   po + va/2,   NW);
label("$\vec{b}$",   po + vb*0.8, SE);
label("$\vec{a_b}$", po + vab/2,  SE);
label("$\vec{c}$",   pc + vc/2,   NE);

shipout(scale(5)*bbox(white));

