import "../systime" as systime;

real ypoints[] = {200, 400, 600, 800, 1000, 1200, 1400};
ticks yticks = LeftTicks(scale(0.6)*Label(align=left), ypoints, Size=2);

xaxis(systime_arrow, xmin=0, xmax=9);
yaxis(yticks, systime_arrow, ymin=0, ymax=1500);

label(scale(0.6)*"{\aa}r", (9, -1500/30.0));
label(scale(0.6)*"kr", (-9/30.0, 1500)  );

real label[]     = {   0,    1,    2,    3,    4,    5,    6,    7,    8};
real opsparing[] = {1000, 1000, 1050, 1103, 1158, 1216, 1276, 1340, 1407};
real rente[]     = {   0,   50,   53,   55,   58,   60,   64,   67,   70};

bars(label, opsparing, rente);

