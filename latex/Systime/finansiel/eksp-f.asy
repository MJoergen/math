import "../systime" as systime;

real xmin =  0.0;
real xmax =  9.0;
real xstep = 1.0;
real ymin =  0.0;
real ymax =  1600;
real ystep = 200.0;

koord("{\aa}r", xmin, xmax, xstep,
      "saldo", ymin, ymax, ystep,
      gitter = true);

real f1(real x)
{
    return 2154.74*exp(log(1.35214)*x);
}

pair p0 = (0.0, 1000);
pair p1 = (1.0, 1050);
pair p2 = (2.0, 1103);
pair p3 = (3.0, 1158);
pair p4 = (4.0, 1216);
pair p5 = (5.0, 1276);
pair p6 = (6.0, 1340);
pair p7 = (7.0, 1407);
pair p8 = (8.0, 1477);

dot(p0);
dot(p1);
dot(p2);
dot(p3);
dot(p4);
dot(p5);
dot(p6);
dot(p7);
dot(p8);

