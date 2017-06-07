import "../systime" as systime;

real ypoints[] = {100, 200, 300, 400, 500, 600, 700, 800, 900, 1000};
ticks yticks = LeftTicks(scale(0.6)*Label(align=left), ypoints, Size=2);

real xmax = 8;
real ymax = 1100;

xaxis(systime_arrow, xmin=0, xmax=xmax);
yaxis(yticks, systime_arrow, ymin=0, ymax=ymax);

label(scale(0.6)*"{\aa}r", (xmax, -ymax/30.0));
label(scale(0.6)*"kr", (-xmax/30.0, ymax)  );

real label[]     = {  1,   2,   3,   4,   5,   6,   7,   8};
real opsparing[] = {  0, 100, 205, 315, 431, 553, 680, 814};
real rente[]     = {  0,   5,  10,  16,  22,  28,  34,  41};
real indskud[]   = {100, 100, 100, 100, 100, 100, 100, 100};

bars(label, opsparing, rente, indskud);
legend("Saldo", "Rente", "Indskud", (1, 700), 58);
