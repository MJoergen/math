import "../systime" as systime;

real ypoints[] = {50, 100, 150, 200, 250, 300 };
ticks yticks = LeftTicks(scale(0.6)*Label(align=left), ypoints, Size=2);

real xmax = 7;
real ymax = 350;

xaxis(systime_arrow, xmin=0, xmax=xmax);
yaxis(yticks, systime_arrow, ymin=0, ymax=ymax);

label(scale(0.6)*"{\aa}r", (xmax, -ymax/30.0));
label(scale(0.6)*"kr", (-xmax/30.0, ymax)  );

real label[]     = {   1,    2,   3,   4,   5,   6};
real afdrag[]    = { 160,  176,  194, 213, 234, 258};
real rente[]     = { 140,  124,  106,  87,  66,  42};

bars(label, afdrag, rente);

