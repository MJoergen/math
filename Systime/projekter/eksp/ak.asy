import systime;

size(12cm,10cm,keepAspect=true);

pen pena = rgb("feb464");
pen penb = rgb("f3a045");
pen penc = rgb("ec860a");

/////////////////////////
// Aksiom nr. 4
/////////////////////////
pair p41 = (-4,0);
pair p42 = (9,0);
pair p43 = (9,6);
pair p44 = (-4,6);

retvinkel(p41, p42, p44, pena+0.5);
retvinkel(p42, p41, p43, pena+0.5);
retvinkel(p43, p42, p44, pena+0.5);
retvinkel(p44, p43, p41, pena+0.5);

draw(p41--p42--p43--p44--cycle, black+1.0);

label("\tiny{$g$}", (3.5,0), align=S);
label("\tiny{$h$}", (9,3), align=E);
label("\tiny{$A=h\cdot g$}", (2.5,3));

label("Aksiom nr. 4",(2.2,-3));


/////////////////////////
// Aksiom nr. 5
/////////////////////////
pair p5A = (15,0);
pair p5B = (21,0);
pair p5C = (19,3);
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

label("Aksiom nr. 5",(24.5,-3));


/////////////////////////
// Aksiom nr. 
/////////////////////////

draw((-4,17)--(5+1/3,17));
dot((2/3-2,17));
dot((2/3+2,17));
label("Aksiom nr. 1",(0.5,13));

draw((10+1/3,15)--(19+2/3,19));
draw((10+1/3,19)--(19+2/3,15));

path x=arc((15,17),1.5,-23.199,23.199);
fill(x--(15,17)--cycle,mediumblue);
draw(x);

path y=arc((15,17),1.5,156.801,203.198);
fill(y--(15,17)--cycle,mediumblue);
draw(y);

label("Aksiom nr. 2",(14.55,13));

draw((24+2/3,18)--(34,18));
draw((24+2/3,16)--(34,16));
draw((27,104/7)--(31+2/3,139/7));

path z=arc((421/15,16),1.5,0,46.975);
fill(z--(421/15,16)--cycle,mediumblue);
draw(z);

path w=arc((449/15,18),1.5,0,46.975);
fill(w--(449/15,18)--cycle,mediumblue);
draw(w);

label("Aksiom nr. 3",(29.45,13));
