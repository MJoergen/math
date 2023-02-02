#!/usr/bin/env python3

# How to generate a circle using only addition/subtraction.
# Assume the circle has a given radius R.
# The idea is to start with the point (x,y) = (R, 0) and
# then generate new points by rotating as follows:
# (x_new) = (1  -a   ) * (x)
# (y_new) = (a  1-a^2) * (y)
# Here a is a small value.
# The quantity x^2+y^2-a*x*y is conserved.
#
# Write x=p+q and y=p-q, then the transformation is:
# (p_new) = (1-a^2/2   a+a^2/2) * (p)
# (q_new) = (-a+a^2/2  1-a^2/2) * (q)
# and the invariant becomes:
# (2-a)*p^2 + (2+a)*q^2.
#
# Finally, write p=s/sqrt(2-a) and q=t/sqrt(2+a)
# Then the transformation is:
# (s_new) = (1-a^2/2          a/2*sqrt(4-a^2)) * (s)
# (t_new) = (-a/2*sqrt(4-a^2)         1-a^2/2) * (t)
# and the invariant becomes:
# s^2+t^2.
#
# In all cases, letting a = 2*sin(v/2)
# the eigenvalues are cos(v) +/- i*sin(v) = exp(+/- i*v).
# With this substitution, the transformation becomes
# (s_new) = (cos(v)  sin(v)) * (s)
# (t_new) = (-sin(v) cos(v)) * (t)
#
# From this it is clear that the period is
# T = 2*pi/v

# In practice the calculations are performed using integer arithmetic,
# and this introduces rounding. This has the effect of increasing the period.


# The period is approximately (2*pi + 4/j)*a.

import math

# Here a1 = 1/a
def calc_circle(xstart, a1):

    x = math.trunc(xstart)
    y = 0

    res = []
    count=0

    for i in range(10*a1):
        oldy = y
        x = x - math.trunc(y/a1)
        y = y + math.trunc(x/a1)
        res.append([x,y])
        count+=1
        if oldy<0 and y>=0:
            break

    return res

xstart = 7*256
a1 = 256
a = 1/a1
res = calc_circle(xstart, a1)
theta = 2*math.asin(a/2)

for i,(x,y) in enumerate(res):
    p,q=(x+y)/2,(x-y)/2
    s,t=math.sqrt(2-a)*p,math.sqrt(2+a)*q
    r = s*s+t*t
    arg = math.atan2(s,t)
    print(x,y,r,arg/theta-i)

print(t, 2*math.pi/t, len(res))

#for i in range(3,14):
#    a = pow(2,i);
#    j = 7
#    period,max2,min2 = calc_circle(j*a, a)
#    print(a, j, period, period/a, max2/min2)
#
#print()
#
#for j in range(4,186,2):
#    a = 4096
#    period,max2,min2 = calc_circle(j*a, a)
#
#    print(a, j, period, period/a, (period/a-2*3.1415926535)*j, 2*period/a-calc_circle(j*a/2,a)[0]/a)
