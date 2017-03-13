import "../systime" as systime;

real ypoints[] = {500, 1000, 1500, 2000, 2500, 3000, 3500};
ticks yticks = LeftTicks(scale(0.6)*Label(align=left), ypoints, Size=2);

real xmax = 12;
real ymax = 3700;

xaxis(systime_arrow, xmin=0, xmax=xmax);
yaxis(yticks, systime_arrow, ymin=0, ymax=ymax);

label(scale(0.6)*"{\aa}r", (xmax, -ymax/30.0));
label(scale(0.6)*"kr", (-xmax/30.0, ymax)  );

real label[]     = {   0,    1,    2,    3,    4,    5,    6,    7,    8,    9,   10,   11};
real opsparing[] = {2000, 2000, 2100, 2205, 2315, 2431, 2553, 2681, 2815, 2956, 3104, 3259};
real rente[]     = {   0,  100,  105,  110,  116,  122,  128,  134,  141,  148,  155,  163};

bars(label, opsparing, rente);

