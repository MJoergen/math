import "../systime" as systime;

real ypoints[] = {200, 400, 600, 800, 1000, 1200, 1400, 1600};
ticks yticks = LeftTicks(scale(0.6)*Label(align=left), ypoints, Size=2);

real xmax = 8;
real ymax = 1700;

xaxis(systime_arrow, xmin=0, xmax=xmax);
yaxis(yticks, systime_arrow, ymin=0, ymax=ymax);

label(scale(0.6)*"{\aa}r", (xmax, -ymax/30.0));
label(scale(0.6)*"kr", (-xmax/30.0, ymax)  );

real label[]     = {    0,    1,    2,   3,   4,   5,   6,   7};
real gaeld[]     = { 1400, 1240, 1064, 870, 657, 423, 165,   0};
real afdrag[]    = {    0,  160,  176, 194, 213, 234, 258, 165};
real rente[]     = {    0,  140,  124, 106,  87,  66,  42,  17};

bars(label, gaeld, afdrag, rente);
legend("G{\ae}ld", "Afdrag", "Rente", (4.5, 1100), 53);

