#! /usr/bin/env python

import math

def accur(x : float) -> float:
    d = math.fabs(4.0*math.atan(1.0)-x)
    return -math.log(d) / math.log(10.0)

k = 1
a = 2.0 * math.sqrt(3.0)
b = 3.0
oldb = b*b/a
l = 0.5 * math.sqrt(3.0)
c = (a+2.0*b)/3.0
prodl = l

print(f"k A_k         B_k         e_a  e_b  l           c           e_c  d           e_d  e            e_e  pl")
print(f"1 {a:.9f} {b:.9f} {accur(a):.2f} {accur(b):.2f} {l:.9f} {c:.9f} {accur(c):.2f}                                    {prodl:.9f}")

while (accur(b)<4.0):

# Recurrence relation
    oldoldb = oldb
    oldb = b
    k += 1
    a = 2.0*a*b / (a+b)
    b = math.sqrt(a*b) # Deliberately uses the new value of a
    l = math.sqrt((1.0 + l)/2.0)
    c = (a+2.0*b)/3.0
    d = (4.0*b-oldb)/3.0
    e = (64.0*b - 20.0*oldb + oldoldb)/45.0
    prodl *= l

    print(f"{k} {a:.9f} {b:.9f} {accur(a):.2f} {accur(b):.2f} {l:.9f} {c:.9f} {accur(c):.2f} {d:.9f} {accur(d):.2f} {e:.9f} \
{accur(e):5.2f} {prodl:.9f}")


