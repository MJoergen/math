import "../systime" as systime;

pair pa = (3.0, 1.0);
pair pb = (3.0, 6.0);

draw(pa..pb, blue_default);

dot(pa);
dot(pb);

label("A", pa, W);
label("B", pb, W);
label("$(x_1,y_1)$", pa, E);
label("$(x_2,y_2)$", pb, E);

xaxis("$x$", NoTicks, systime_arrow);
yaxis("$y$", NoTicks, systime_arrow);

shipout(scale(5)*bbox(white));
