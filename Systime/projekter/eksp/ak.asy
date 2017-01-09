import systime;

size(12cm, 10cm, keepAspect=true);

pen pena = yellow_thin*0.6 + white*0.4;
pen penb = yellow_thin*0.8 + white*0.2;
pen penc = yellow_thin;

/////////////////////////
// Aksiom nr. 4
/////////////////////////
pair p41 = (-4,0);
pair p42 = (9,0);
pair p43 = (9,6);
pair p44 = (-4,6);

retvinkel(p41, p42, p44, penc+1.0);
retvinkel(p42, p41, p43, penc+1.0);
retvinkel(p43, p42, p44, penc+1.0);
retvinkel(p44, p43, p41, penc+1.0);

draw(p41--p42--p43--p44--cycle, black+1.0);

label("\scriptsize{$g$}", 0.5*(p41+p42), align=S);
label("\scriptsize{$h$}", 0.5*(p42+p43), align=E);
label("\scriptsize{$A=h\cdot g$}", 0.5*(p41+p43));

label("Aksiom nr 4", (2.2,-3));


/////////////////////////
// Aksiom nr. 5
/////////////////////////
pair p5A = (14,0);
pair p5B = (20,0);
pair p5C = (18,3);
pair p5A1 = (22,0);
pair p5B1 = (34,0);
pair p5C1 = (30,6);

label("\scriptsize{$A$}", p5A, align=S);
label("\scriptsize{$B$}", p5B, align=S+0.4*W);
label("\scriptsize{$C$}", p5C, align=N);
label("\scriptsize{$c$}", 0.5*(p5A+p5B), align=S);
label("\scriptsize{$a$}", 0.5*(p5B+p5C), align=0.5*NE);
label("\scriptsize{$b$}", 0.5*(p5C+p5A), align=N);

vinkelbue(p5A, p5B, p5C, 1.5, penc);

vinkelbue(p5B, p5C, p5A, 1.5, penc);
vinkelbue(p5B, p5C, p5A, 1.2, pena);

vinkelbue(p5C, p5A, p5B, 1.5, penc);
vinkelbue(p5C, p5A, p5B, 1.2, penb);
vinkelbue(p5C, p5A, p5B, 0.9, pena);

label("\scriptsize{$A_1$}", p5A1, align=S);
label("\scriptsize{$B_1$}", p5B1, align=S);
label("\scriptsize{$C_1$}", p5C1, align=N);
label("\scriptsize{$c_1$}", 0.5*(p5A1+p5B1), align=S);
label("\scriptsize{$a_1$}", 0.5*(p5B1+p5C1), align=E);
label("\scriptsize{$b_1$}", 0.5*(p5C1+p5A1), align=N);

vinkelbue(p5A1, p5B1, p5C1, 1.5, penc);

vinkelbue(p5B1, p5C1, p5A1, 1.5, penc);
vinkelbue(p5B1, p5C1, p5A1, 1.2, penb);

vinkelbue(p5C1, p5A1, p5B1, 1.5, penc);
vinkelbue(p5C1, p5A1, p5B1, 1.2, penb);
vinkelbue(p5C1, p5A1, p5B1, 0.9, pena);

draw(p5A--p5B--p5C--cycle, black+1.0);
draw(p5A1--p5B1--p5C1--cycle, black+1.0);

label("Aksiom nr 5", (24.5,-3));


/////////////////////////
// Aksiom nr. 1
/////////////////////////

draw((-4,13)--(5+1/3,13), black+1.0);
dot((2/3-2,13), penc+5.0);
dot((2/3+2,13), penc+5.0);
label("Aksiom nr 1", (0.5,9));


/////////////////////////
// Aksiom nr. 2
/////////////////////////

pair p20 = (15, 13);
pair p2u = (4+2/3, 2);
pair p2d = (4+2/3, -2);

vinkelbue(p20, p20+p2u, p20+p2d, 1.5, penc);
vinkelbue(p20, p20-p2u, p20-p2d, 1.5, penc);

draw (p20-p2u -- p20+p2u, black+1.0);
draw (p20-p2d -- p20+p2d, black+1.0);

label("Aksiom nr 2", (14.55,9));


/////////////////////////
// Aksiom nr. 3
/////////////////////////

pair p30 = (421/15, 12);
pair p31 = (449/15, 14);
pair p3R = (1, 0);
pair p3U = p31-p30;

vinkelbue(p30, p30+p3R, p30+p3U, 1.5, penc);
vinkelbue(p31, p31+p3R, p31+p3U, 1.5, penc);

draw((24+2/3,14)--(34,14), black+1.0);
draw((24+2/3,12)--(34,12), black+1.0);
draw((27,76/7)--(31+2/3,111/7), black+1.0);

label("Aksiom nr 3", (29.45,9));

