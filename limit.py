#!/usr/bin/env python3

import math

# Given a finite sequence of numbers a_n, what is a good estimate of the
# limit as n goes to infinity ?
#
# In general this is hard, so we approach this problem in special
# cases, where we make some assumptions on the limiting behaviour of the
# sequence.
#
# Case 1 : a_n = a + b * c^n, where |c| < 1.
#
# In this case the limit a can be estimated as
# a = (a_{n+2} * a_n - a_{n+1}^2)/(a_{n+2} + a_n - 2*a_{n+1})
#
# Case 2 : a_n = a + b/(n+c)
#
# In this case the limit a can be estimated as
# a = (a_n*(a_{n+2}-a_{n+1}) - a_{n+2}*(a_{n+1}-a_n))/(a_{n+2} - 2*a_{n+1} + a_n)

def test(s, l, a):
    print(s, l)
    print("list: ", end='')
    for e in a:
        print("%8.5f"%(e), end='')
    print()
    calc_lim_exp(a)
    calc_lim_pow(a)
    print()

def calc_lim_exp(a):
    lims = []
    for n in range(len(a)-2):
        lims.append((a[n+2]*a[n]-a[n+1]*a[n+1])/(a[n+2]+a[n]-2*a[n+1]))
    print(" exp: ", end='')
    for e in lims:
        print("%8.5f"%(e), end='')
    print()

def calc_lim_pow(a):
    lims = []
    for n in range(len(a)-2):
        lims.append((a[n]*(a[n+2]-a[n+1]) - a[n+2]*(a[n+1]-a[n]))/(a[n+2] - 2*a[n+1] + a[n]))
    print(" pow: ", end='')
    for e in lims:
        print("%8.5f"%(e), end='')
    print()

seq0 = [2+3*math.exp(-n) for n in range(10)]
seq1 = [3+4/(n+1) for n in range(10)]
seq2 = [1+2*math.exp(-n)-4*math.exp(-2*n) for n in range(10)]
seq3 = [3+4*math.atan(n)/math.pi for n in range(10)]

test("An exact exponential", 2, seq0)
test("An exact power", 3, seq1)
test("An approximate exponential", 1, seq2)
test("An approximate power", 5, seq3)

