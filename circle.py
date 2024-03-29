#!/usr/bin/env python3

# INTRODUCTION
# How to generate a circle using only addition/subtraction?
#
# Assume the circle has a given radius R.
# The idea is to start with the point (x,y) = (R, 0) and
# then generate new points by rotating as follows:
# x_new = 1*x - a*y
# y_new = a*x + (1-a^2)*y
#
# In matrix notation this can be written as:
# (x_new) = (1  -a   ) * (x)
# (y_new) = (a  1-a^2) * (y)
# Here a is a small value.
# The important point here is that this matrix has determinant one.
#
# CONIC SECTION
# The above generates a sequence of points.
# All points in this sequence lie of a conic section given by the
# equation x^2 + y^2 - a*x*y = R^2.
# In other words, if (x,y) satisfies this equation, then
# so does (x_new, y_new). This can be verified purely algebraically.
# This conic section happens to describe an ellipse tilted 45 degrees.
#
# EXACT SOLUTION
# In the following we find a general formula for x_n and y_n
# as function of n, where x_0 = R and y_0 = 0.
# First write x=p+q and y=p-q, then the transformation is:
# (p_new) = (1-a^2/2   a+a^2/2) * (p)
# (q_new) = (-a+a^2/2  1-a^2/2) * (q)
# and the invariant equation becomes:
# (2-a)*p^2 + (2+a)*q^2 = R^2.
# Once again, the determinant is one.
# The initial values are p_0 = R/2 and q_0 = R/2.
#
# Second, write p=s/sqrt(2-a) and q=t/sqrt(2+a)
# Then the sequence is generated by:
# (s_new) = (1-a^2/2          a/2*sqrt(4-a^2)) * (s)
# (t_new) = (-a/2*sqrt(4-a^2)         1-a^2/2) * (t)
# and the invariant equation becomes:
# s^2+t^2 = R^2.
# In other words, in the (s,t) plane the sequence of points lie on a circle.
# The initial values are s_0 = sqrt(2-a) * R/2 and t_0 = sqrt(2+a) * R/2.
# Again the determinant is one.
#
# Now we introduce a new parameter v by letting a = 2*sin(v/2).
# With this substitution, the sequence generation can
# be described more simply by:
# (s_new) = (cos(v)  sin(v)) * (s)
# (t_new) = (-sin(v) cos(v)) * (t)
# And now we see that in the (s,t) plane the sequence of points are
# generated by a rotation with a fixed angle of v.
# The initial values are s_0 = R*cos(pi/4+v/4) and t_0 = R*sin(pi/4+v/4).
#
# Finally, we introduce polar coordinates s = r*cos(w) and t = r*sin(w)
# The the sequence is simply generated by:
# r_new = r
# w_new = w - v
# The initial values are r_0 = R and w_0 = pi/4+v/4.
# This sequence can finally be solved in general to get
# r_n = R
# w_n = C - n*v
# where C = pi/4 + v/4 is a constant.
#
# DETERMINE THE PERIOD OF REVOLUTION
# From the above it is clear that the period is
# w_T = w_0 - 2*pi, i.e.
# T = 2*pi/v
#
# ROUNDING ERROR
# In practice the calculations on x and y are performed using integer arithmetic,
# and this introduces rounding. This apparently has the effect of increasing
# the period.
#
# This change in period can be seen by a slight phase shift, specifically in that
# the value C is not constant.
# So for each point (r_n, w_n) we calculate p_n = w_n + n*v. This value is constant
# in the real case, but decreases approximately linearly in the truncated case.
# The slope of this line seems to be well approximated by 4/(R*a).
# The output column "alpha" is the numerator (4) in this fraction.
#
# The final result of this program is that in the truncated case the period is approximately:
# T == (2*pi + 4/(R*a)) / a.

import math

# Generate the sequence of points corresponding to one full period
# The starting point is (xstart, 0) and the parameter is a.
# In the real case, x and y are real numbers.
# However, in the truncated case, x and y are integers.
def calc_circle(xstart, a):
    x = math.trunc(xstart)  # This just makes sure the initial value is an integer point
    y = 0
    res = []
    while True:
        oldy = y
        x = x - math.trunc(y*a) # Here the result of the multiplication is truncated
        y = y + math.trunc(x*a) # Here the result of the multiplication is truncated
        res.append([x,y])
        if oldy<0 and y>=0:     # Stop after one full circle
            break
    return res

# Calculate r and w such that s=r*cos(w) and t=r*sin(w)
def calc_rw(x, y, a):
    p,q = (x+y)/2, (x-y)/2
    s,t = math.sqrt(2-a)*p, math.sqrt(2+a)*q
    r,w = math.sqrt(s*s+t*t), math.atan2(t,s)
    return r,w

# Use Welford's algotithm to calculate mean and standard deviation
def get_stat(v):
    vmin = 0
    vmax = 0
    vlen = 0
    vavg = 0
    vm2  = 0
    for e in v:
        if e < vmin or vlen == 0:
            vmin = e
        if e > vmax or vlen == 0:
            vmax = e
        vlen += 1
        delta = e - vavg
        vavg += delta / vlen
        delta2 = e - vavg
        vm2 += delta*delta2
    # Return: count, max, min, mean, stddev, and range.
    return (vlen, vmax, vmin, vavg, math.sqrt(vm2/vlen), vmax-vmin)

def main():
    xstart = 1024*1024 # Choose a large circle
    a = 1/4 # Start with a large step size
    while a >= 1/65536:
        res = calc_circle(xstart, a)
        v = 2*math.asin(a/2)

        rvec = []
        pvec = []

        # Iterate over all points
        for i,(x,y) in enumerate(res):
            r,w = calc_rw(x,y,a)
            p = (w+i*v)%(2*math.pi) # Calculate phase difference between real and truncated case
            # Accumulate statistics on r_n and p_n.
            rvec.append(r)
            pvec.append(p)
            #print("%7.1f, %7.1f, %5.1f, %8.5f, %8.5f" % (x,y,r,w,p))

        rstat = get_stat(rvec)
        pstat = get_stat(pvec)
        alpha = pstat[5]*a*xstart # Here pstat[5] is the range (max-min) of p_n.
        pstat += (alpha,) # Append to list
        print("a=%9.7f, v=%9.7f, period=%8.1f, expected=%8.1f" % (a,v,2*math.pi/v,(2*math.pi + 4/(xstart*a))/a))
        print("rvec: len=%6d, max=%12.1f, min=%12.1f, avg=%12.1f, stddev=%7.1f, range=%12.1f" % (rstat))
        print("pvec: len=%6d, max=%12.5f, min=%12.5f, avg=%12.5f, stddev=%7.5f, range=%12.5f, alpha=%6.2f" % (pstat))
        print()
        a /= 2 # Repeat with smaller step size

if __name__ == '__main__':
    main()

