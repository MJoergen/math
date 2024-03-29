#!/usr/bin/env python3
# vim: tabstop=4 shiftwidth=4 expandtab

# References:
# https://www.youtube.com/watch?v=Ct3lCfgJV_A
# https://www.quora.com/How-do-you-find-the-positive-integer-solutions-to-frac-x-y+z-+-frac-y-z+x-+-frac-z-x+y-4
# https://ami.uni-eszterhazy.hu/uploads/papers/finalpdf/AMI_43_from29to41.pdf

# Output generated:
# nmax=200, depth=123, maxdigits=420000
# n=  4, s=-4            , t=28            , x=       11, y=        4, z=       -1, m=   9, d=    81
# n=  6, s=-8            , t=104           , x=       23, y=        7, z=       -3, m=  11, d=   134
# n= 10, s=-1            , t=10            , x=       23, y=       19, z=      -16, m=  13, d=   190
# n= 12, s=-216          , t=4824          , x=      247, y=      215, z=     -187, m=  35, d=  2707
# n= 14, s=-17           , t=510           , x=       13, y=        8, z=       -7, m=  47, d=  1876
# n= 16, s=-676          , t=15652         , x=     3023, y=     2060, z=    -1853, m=  11, d=   414
# n= 18, s=-2888/9       , t=298376/27     , x=    42753, y=    38947, z=   -35647, m=  49, d= 10323
# n= 24, s=-1764         , t=50652         , x=     1271, y=      731, z=     -676, m= 107, d= 33644
# n= 28, s=-167648/49    , t=8072896/343   , x=   283577, y=    37627, z=   -27477, m= 121, d= 81853
# n= 32, s=-1620         , t=86580         , x=     2747, y=     2212, z=    -2117, m=  65, d= 14836
# n= 34, s=-1            , t=62            , x=      359, y=      235, z=     -224, m=  11, d=   302
# n= 38, s=-3872         , t=187968        , x=    12893, y=     8007, z=    -7657
# n= 42, s=-7220/49      , t=4347580/343   , x=   113040, y=   108101, z=  -104339
# n= 46, s=-7396         , t=297388        , x=    88703, y=    38147, z=   -36200, m= 201, d=198771
# n= 48, s=-833/9        , t=245854/27     , x=    15257, y=    14052, z=   -13667, m= 311, d=418086
# n= 58, s=-102541/25    , t=51390548/125  , x=    91600, y=    77443, z=   -75733, m= 221, d=244860
# n= 60, s=-9            , t=1098          , x=      179, y=       68, z=      -65, m=  61, d=  9188
# n= 76, s=-21316        , t=1106972       , x=   415583, y=   141115, z=  -135628, m=  65, d= 23662
# n= 82, s=-21160        , t=1734200       , x=     6835, y=     3377, z=    -3293, m= 157, d= 85465
# n= 92, s=-45           , t=8400          , x=      263, y=      220, z=     -217, m= 321, d=252817
# n= 94, s=-33124        , t=1915732       , x=   794879, y=   243704, z=  -235229, m= 193, d=219219
# n=102, s=-945          , t=193410        , x=     1864, y=     1859, z=    -1825
# n=114, s=-4212         , t=933660        , x=     1043, y=     1003, z=     -992, m=   7, d=   136
# n=132, s=-2291544/49   , t=2511331992/343, x= 19900769, y= 11702515, z=-11550559
# n=136, s=-70756        , t=4931108       , x=  2440943, y=   625372, z=  -607405, m=  65, d= 26942
# n=144, s=-756          , t=218988        , x=     1315, y=     1307, z=    -1292
# n=146, s=-200          , t=58920         , x=     2513, y=     2417, z=    -2397, m= 307, d=259164
# n=152, s=-3715220/49   , t=3529243500/343, x=   648025, y=   287676, z=  -283399
# n=158, s=-2592         , t=816192        , x=   103519, y=   102509, z=  -101539
# n=160, s=-121          , t=39050         , x=     1619, y=     1516, z=    -1505
# n=162, s=-500          , t=163100        , x=      589, y=      581, z=     -576
# n=166, s=-5096         , t=1667848       , x=    16451, y=    16099, z=   -15975
# n=182, s=-392          , t=143640        , x=     2021, y=     1983, z=    -1969
# n=186, s=-133956       , t=10929492      , x=   699527, y=   153680, z=  -149917
# n=200, s=-15341        , t=5882940       , x=     4748, y=     4521, z=    -4495
#
# Time taken:  1228.6 minutes.
# Found non-torsion points on 35 curves.
# Found positive solutions on 22 curves.
#
# Note: The solutions for n=34, n=94, and n=114 were not mentioned in the paper
# by Bremner and Macleod.

## PART 1 - INTRODUCTION

# This little program attempts to solve the equation
# (1) : x/(y+z) + y/(x+z) + z/(x+y) = n
# for any given integer n.
# We want positive integer solutions (x,y,z).
#
# This equation as stated is invariant for all permutations of (x,y,z).
#
# For n=4 a solution is (-11, -4, 1).

# Since we'll be working with fractions let's import the module
from fractions import Fraction
from typing import Tuple
from typing import Iterator
from typing import Optional
from typing import List

class Equation1:
    x: Fraction
    y: Fraction
    z: Fraction

    def __init__(self, x, y, z) -> None:
        self.x = x
        self.y = y
        self.z = z

    # This function calculates the left-hand-side of equation (1)
    def eval(self):
        return Fraction(self.x,self.y+self.z) + Fraction(self.y,self.x+self.z) + Fraction(self.z,self.x+self.y)

# Verify the known solution for n=4 (all permutations)
assert Equation1(-11,  -4,   1).eval() == 4
assert Equation1(-11,   1,  -4).eval() == 4
assert Equation1( -4, -11,   1).eval() == 4
assert Equation1( -4,   1, -11).eval() == 4
assert Equation1(  1,  -4, -11).eval() == 4
assert Equation1(  1, -11,  -4).eval() == 4


## PART 2 - REDUCE DIMENSION OF PROBLEM

# Since this is homogenous in x,y,z, we can set z=1. Re-arranging gives:
# x(x+1)(x+y) + y(y+1)(x+y) + (x+1)(y+1) = n(x+1)(y+1)(x+y)
# Here we want positive rational solutions.
#
# Multiplying out the above we get:
# (2) : x^3 - (n-1)(y+1)x^2 - x((n-1)y^2+(2n-3)y+(n-1)) + y^3-(n-1)y^2-(n-1)y+1 = 0
#
# With the permutations, a solution (x,y) implies the following
# other solutions: (y,x), (1/x, y/x), (y/x, 1/x), (1/y, x/y), and (x/y, 1/y).
#
# For n=4 the known solutions are (-11, -4), (-4, -11), (-1/11, 4/11),
# (4/11, -1/11), (-1/4, 11/4), and (11/4, -1/4)
#
# Additional trivial solutions (for all n) are (-1, -1), (-1, 0), and (-1, 1).

class Equation2:
    a: Fraction
    b: Fraction
    c: Fraction
    d: Fraction

    def __init__(self, y: Fraction, n: int) -> None:
        self.a = Fraction(1)
        self.b = -(n-1)*(y+1)
        self.c = -((n-1)*y*y+(2*n-3)*y+(n-1))
        self.d = y*y*y-(n-1)*y*y-(n-1)*y+1

    # This function calculates the left-hand-side of equation (2)
    def eval(self, x):
        return (((self.a*x+self.b)*x+self.c)*x+self.d)

# Convert from rational (x,y) to integer (x,y,z) solution
def calc_xyz(x: Fraction, y: Fraction) -> Tuple[int, int, int]:
    assert x.denominator == y.denominator
    return (x.numerator, y.numerator, y.denominator)

def sort_xyz(x: int, y: int, z: int) -> Tuple[int, int, int]:
    res = sorted((x, y, z),key=abs,reverse=True)
    if res[0] >= 0:
        return (res[0], res[1], res[2])
    else:
        return (-res[0], -res[1], -res[2])

# Verify trivial solutions (for various n values)
assert Equation2(Fraction(-1), 1234).eval(-1) == 0
assert Equation2(Fraction( 0), 2345).eval(-1) == 0
assert Equation2(Fraction( 1), 3456).eval(-1) == 0

# Verify known solutions for n=4.
assert Equation2(Fraction(-4), 4).eval(Fraction(-11)) == 0
assert Equation2(Fraction(-11), 4).eval(Fraction(-4)) == 0
assert Equation2(Fraction(-1,4), 4).eval(Fraction(11,4)) == 0
assert Equation2(Fraction(11,4), 4).eval(Fraction(-1,4)) == 0
assert Equation2(Fraction(-1,11), 4).eval(Fraction(4,11)) == 0
assert Equation2(Fraction(4,11), 4).eval(Fraction(-1,11)) == 0

# Verify we can recover integer solution
assert calc_xyz(-Fraction(1,4), Fraction(11,4)) == (-1, 11, 4)
assert Equation1(*calc_xyz(-Fraction(1,4), Fraction(11,4))).eval() == 4


## PART 3 - SIMPLIFY EQUATION

# Before proceeding, we make a substitution to simplify the problem
# Set x=u+v and y=u-v
# The inverse mapping is u=(x+y)/2 and v=(x-y)/2.
#
# Inserting into equation (2) gives after some algebra:
# (3) : v^2 = (u+1)*((2n-4)u^2 + (2n-1)u - 1)/((2n+4)u-1)
#
# In the new variables the known solutions for n=4 are
# (u,v) = (-15/2, +/- 7/2)
# (u,v) = (5/4,   +/- 3/2)
# (u,v) = (3/22,  +/- 5/22)
#
# The trivial solutions (for all n) are:
# (u,v) = (-1, +/- 0)
# (u,v) = (-1/2, +/- 1/2)
# (u,v) = (0, +/- 1)
#
# Notice that the symmetry (x,y) -> (y,x) of equation (2) maps to the symmetry
# v -> -v of equation (3). In this regard the new equation is simpler, because
# it contains no odd powers of v.

class Equation3:
    a: int
    b: int
    c: int
    d: int
    e: int

    def __init__(self, n: int) -> None:
        self.a = 2*n-4
        self.b = 2*n-1
        self.c = -1
        self.d = 2*n+4
        self.e = -1

    # This function calculates the left-hand-side of equation (3)
    def eval(self, u: Fraction) -> Fraction:
        return (u+1)*((self.a*u+self.b)*u+self.c)/(self.d*u+self.e)

# Convert from (u,v) to (x,y) solution
def calc_xy(u: Fraction, v: Fraction) -> Tuple[Fraction, Fraction]:
    return (u+v, u-v)

# Verify known solutions
assert Equation3(4).eval(Fraction(-15,2)) == Fraction(7,2)**2
assert Equation3(4).eval(Fraction(5,4))   == Fraction(3,2)**2
assert Equation3(4).eval(Fraction(3,22))  == Fraction(5,22)**2

assert calc_xy(Fraction(-15,2), Fraction(7,2)) == (-4, -11)
assert calc_xyz(*calc_xy(Fraction(-15,2), Fraction(7,2))) == (-4, -11, 1)
assert Equation1(*calc_xyz(*calc_xy(Fraction(-15,2), Fraction(7,2)))).eval() == 4

# Verify trivial solutions (for various n values)
assert Equation3(1234).eval(Fraction(-1))   == Fraction(0)**2
assert Equation3(2345).eval(Fraction(-1,2)) == Fraction(1,2)**2
assert Equation3(3456).eval(Fraction(0))    == Fraction(1)**2


## PART 4 - SIMPLIFY EQUATION AGAIN

# We now introduce yet another substitution to simplify equation (3) even further
# Set s = -8(n+3)*(u+1)/(2n+4)u-1)
#     t = 8(n+3)(2n+5)*v/(2n+4)u-1)
# The inverse transform is
# u = (s - 8(n+3))/((2n+4)s + 8(n+3))
# v = -t/((2n+4)s + 8(n+3))
#
# The new equation becomes
# (4) : t^2 = s^3 + (4n^2+12n-3)s^2 + 32(n+3)s
#
# In the new variables the known solutions for n=4 are
# (s,t) = (-4, 28)    => (x,y,z) = (-11, -4,  1)
# (s,t) = (-9, 78)    => (x,y,z) = ( 11, -1,  4)
# (s,t) = (-100, 260) => (x,y,z) = (  4, -1, 11)
#
# The previously mentioned trivial solutions are
# (s,t) = (0, 0)                 => (x,y,z) = (-1, -1, 1)
# (s,t) = (4, 4(2n+5))           => (x,y,z) = (-1,  0, 1)
# (s,t) = (8(n+3), 8(n+3)(2n+5)) => (x,y,z) = (-1,  1, 1)

class Equation4:
    g: int
    h: int

    def __init__(self, n: int) -> None:
        self.g = 4*n*n+12*n-3
        self.h = 32*(n+3)

    # This function calculates the left-hand-side of equation (4)
    def eval(self, s: Fraction) -> Fraction:
        return ((s+self.g)*s+self.h)*s

# Convert from (s,t) to (u,v) solution
def calc_uv(s: Fraction, t: Fraction, n: int) -> Tuple[Fraction, Fraction]:
    return ((s - 8*(n+3))/((2*n+4)*s + 8*(n+3)),
            -t/((2*n+4)*s + 8*(n+3)))

# Verify known solutions
assert Equation4(4).eval(Fraction(-4))   == Fraction(28)**2
assert Equation4(4).eval(Fraction(-9))   == Fraction(78)**2
assert Equation4(4).eval(Fraction(-100)) == Fraction(260)**2

assert calc_uv(Fraction(-4), Fraction(28), 4) == (Fraction(-15, 2), Fraction(-7, 2))
assert calc_xy(*calc_uv(Fraction(-4), Fraction(28), 4)) == (-11, -4)
assert calc_xyz(*calc_xy(*calc_uv(Fraction(-4), Fraction(28), 4))) == (-11, -4, 1)
assert Equation1(*calc_xyz(*calc_xy(*calc_uv(Fraction(-4), Fraction(28), 4)))).eval() == 4

# Verify trivial solutions (for various n values)
assert Equation4(1234).eval(Fraction(0))          == 0**2
assert Equation4(2345).eval(Fraction(4))          == (4*(2*2345+5))**2
assert Equation4(3456).eval(Fraction(8*(3456+3))) == (8*(3456+3)*(2*3456+5))**2

assert calc_xyz(*calc_xy(*calc_uv(-Fraction(4), Fraction(28), 4))) == (-11, -4, 1)
assert calc_xyz(*calc_xy(*calc_uv(-Fraction(9), Fraction(78), 4))) == (11, -1, 4)
assert calc_xyz(*calc_xy(*calc_uv(-Fraction(100), Fraction(260), 4))) == (4, -1, 11)
assert calc_xyz(*calc_xy(*calc_uv(Fraction(0), Fraction(0), 1234))) == (-1, -1, 1)
assert calc_xyz(*calc_xy(*calc_uv(Fraction(4), Fraction(4*(2*2345+5)), 2345))) == (-1, 0, 1)
assert calc_xyz(*calc_xy(*calc_uv(Fraction(8*(3456+3)), Fraction(8*(3456+3)*(2*3456+5)), 3456))) == (-1, 1, 1)


## PART 5 - GENERATING MORE SOLUTIONS

# The equation (4) is an elliptic curve and therefore
# it admits a group structure.
#
# If we have a solution (s,t) to equation (4) then
# the slope of the curve can be calculated as follows
# dt/ds = (3s^2 + 2(4n^2+12n-3)s + 32(n+3))/(2t)
#
# Inserting the line equation t=as+b into equation (4) leads
# to a cubic equation in s, where the sum of roots becomes
# s1+s2+s3 = a^2-(4n^2+12n-3).
#
# Since the tangent is a double root, we can easily
# calculate the third intersection point.
#
# If instead we have two existing solutions (s1,t1) and (s2,t2)
# then a third solution can be found be first calculating the line
# through the points by a=(t2-t1)/(s2-s1) and b=t1-a*s1,
# and then using the above sum-of-roots to calculate the new solution s3.
#
# The above shows that for two point on the elliptic curve
# we can generate a third point, using either the slope (if the two
# points are the same) or the secant (if the two points are different).

# We introduce additional helper classes
class Line:
    a: Fraction
    b: Fraction

    def __init__(self, a, b) -> None:
        self.a = a
        self.b = b

    def eval(self, s) -> Fraction:
        return self.a*s+self.b

class Point:
    s: Fraction
    t: Fraction

    def __init__(self, s, t) -> None:
        self.s = s
        self.t = t

    def __str__(self) -> str:
        return f"({self.s},{self.t})"

    # Useful for sorting points based on the "complexity" of the first coordinate
    def __eq__(self, other):
        return self.s == other.s and self.t == other.t

    def __lt__(self, other):
        return abs(self.s.denominator)  < abs(other.s.denominator) or \
              (abs(self.s.denominator) == abs(other.s.denominator) and \
               abs(self.s.numerator)    < abs(other.s.numerator))


# This function calculates the slope of the curve at a given point
def calc_slope(p: Point, n: int) -> Fraction:
    return (3*p.s*p.s + (8*n*n+24*n-6)*p.s + 32*(n+3))/(2*p.t)

# This function calculates the sum of the intersections between a line
# and equation (4).
def sum_roots(l: Line, n: int) -> Fraction:
    return l.a*l.a-(4*n*n+12*n-3)

# Calculate the tangent line at a given point
def calc_tangent(p: Point, n: int) -> Line:
    a = calc_slope(p, n)
    b = p.t - a*p.s
    return Line(a,b)

# If we have a single point satisfying equation (4) then the tangent will
# intersect the curve in a second point easily calculated as follows:
def new_point_tangent(p1: Point, n: int) -> Point:
    tangent = calc_tangent(p1, n)
    root_sum = sum_roots(tangent, n)
    s3 = root_sum - p1.s - p1.s # Subtract twice, because a tangent is a double root
    t3 = tangent.eval(s3)
    return Point(s3,-t3) # Invert t

def calc_secant(p1: Point, p2: Point) -> Line:
    a = (p2.t-p1.t)/(p2.s-p1.s)
    b = p1.t - a*p1.s
    return Line(a,b)

def new_point_secant(p1: Point, p2: Point, n: int) -> Point:
    secant = calc_secant(p1, p2)
    root_sum = sum_roots(secant, n)
    s3 = root_sum - p1.s - p2.s
    t3 = secant.eval(s3)
    return Point(s3,-t3) # Invert t

# This is the general point addition algorithm
# Special care is needed to account for the point at infinity,
# which is represented by the value "None".
def add_point(p1: Optional[Point], p2: Point, n: int) -> Point:
    if p1 is None:
        return p2
    if p1==p2:
        return new_point_tangent(p1, n)
    else:
        return new_point_secant(p1, p2, n)


## PART 6 - SEARCHING FOR SMALL SOLUTIONS

# We are finally ready to tackle the problem of finding more solutions.
# We start by doing a brute force search for small rational solutions
# to equation (4).
# We see from the previous analysis that the solutions of interest have negative s.
# Equation (4) is positive when s is larger than -(4n^2+12n-3). Since n+3 is a common
# factor in the above equations, I choose to consider the interval from -4n(n+3) to 0.

import gmpy2 # type: ignore
def is_square(f: Fraction) -> bool:
    return gmpy2.is_square(f.numerator) and gmpy2.is_square(f.denominator)
def isqrt(f: Fraction) -> Fraction:
    return Fraction(int(gmpy2.isqrt(f.numerator)), int(gmpy2.isqrt(f.denominator)))

# This generates a sorted list of candidate values for s in the range ]-4n(n+3),0[.
# The first values are all integers.
# The remaining values are fractions ordered with the smallest denominator first.
import math
def gen_candidates(end: int, depth: int) -> Iterator[Fraction]:
    for denominator in range(1,depth):
        for numerator in range(1,denominator*end):
            if math.gcd(denominator,numerator) == 1:
                f = Fraction(-numerator,denominator)
                if gmpy2.is_square(f.denominator):
                    yield f

assert [f for f in gen_candidates(6, 5)] == \
        [Fraction(-1, 1), Fraction(-2, 1), Fraction(-3, 1), Fraction(-4, 1), \
        Fraction(-5, 1), Fraction(-1, 4), Fraction(-3, 4), Fraction(-5, 4), \
        Fraction(-7, 4), Fraction(-9, 4), Fraction(-11, 4), Fraction(-13, 4), \
        Fraction(-15, 4), Fraction(-17, 4), Fraction(-19, 4), Fraction(-21, 4), \
        Fraction(-23, 4)]

# This simply searches all the "simple" rational numbers s between
# -4n(n+3) and 0, inserts into equation (4), and checks whether the
# right hand side evaluates to a square of a rational. If so,
# we've found a solution.
def find_a_small_solution(n: int, depth: int) -> Optional[Point]:
    for s in gen_candidates(4*n*(n+3), depth):
        t2 = Equation4(n).eval(s)
        if t2 >=0 and is_square(t2):
            t = isqrt(t2)
            if s != 0 and s != 4 and s != 8*(n+3):
                return Point(s,t)
    return None

assert find_a_small_solution(4, 10) == Point(-4, 28)


## PART 7 - GENERATING A FAMILY OF SOLUTIONS

# This is the main algorithm, stepping through the points indefinitely

# This defines the list of the six torsion points.
# Note that "None" is meant to correspond to the point at infinity.
def torsions_points(n: int) -> List[Optional[Point]]:
    return [None, \
        Point(Fraction(0), Fraction(0)), \
        Point(Fraction(4), Fraction(4*(2*n+5))), \
        Point(Fraction(4), Fraction(-4*(2*n+5))), \
        Point(Fraction(8*(n+3)), Fraction(8*(n+3)*(2*n+5))), \
        Point(Fraction(8*(n+3)), Fraction(-8*(n+3)*(2*n+5)))]

# This takes a single solution and returns the six equivalent points
# obtained by adding the torsion points.
def find_equivalent_points(n: int, p: Point) -> Iterator[Point]:
    for t in torsions_points(n):
        yield add_point(t,p,n)

# Verify the previously known equivalent solutions
assert [p for p in find_equivalent_points(4, Point(Fraction(-4), Fraction(28)))] == \
        [Point(Fraction(-4), Fraction(28)), \
        Point(Fraction(-56), Fraction(-392)), \
        Point(Fraction(-100), Fraction(260)), \
        Point(Fraction(-9), Fraction(-78)), \
        Point(Fraction(-224, 9), Fraction(5824, 27)), \
        Point(Fraction(-56, 25), Fraction(-728, 125))]

assert [calc_xyz(*calc_xy(*calc_uv(p.s, p.t, 4))) for p in find_equivalent_points(4, Point(Fraction(-4), Fraction(28)))] == \
        [(-11, -4, 1), \
        (-5, 9, 11), \
        (4, -1, 11), \
        (-1, 11, 4), \
        (11, -5, 9), \
        (-9, -11, 5)]

# This calculates the sequence start+m*inc, for m=1,2,..., where start is
# one of the six torsion points (including infinity).
def calc_sequence(start: Optional[Point], inc: Point, n: int) -> Iterator[Tuple[int, Point]]:
    point = add_point(start, inc, n)
    m=1
    while True:
        assert Equation4(n).eval(point.s) == point.t**2
        yield (m,point)
        point = add_point(point, inc, n)
        m += 1

# This finds the first positive solution to equation (1)
import logging
def find_positive_solution(start: Optional[Point], inc: Point, n: int, maxdigits: int) -> Tuple[int, int]:
    tstart = time.perf_counter()
    for (m,p) in calc_sequence(start, inc, n):
        (x,y,z) = calc_xyz(*calc_xy(*calc_uv(p.s, p.t, n)))
        digits = max(len(str(x)), len(str(y)), len(str(z)))
        tend = time.perf_counter()
        if x>0 and y>0:
            assert Equation1(x,y,z).eval() == n
            logging.info(f"n={n:2d}, m={m:4d}, d={digits:7d}, time={tend-tstart:6.1f}, t={str(start):20s}, FOUND!!!")
            return (m,digits)
        elif digits>maxdigits:
            logging.info(f"n={n:2d}, m={m:4d}, d={digits:7d}, time={tend-tstart:6.1f}, t={str(start):20s}, TOO BIG!!")
            break
        logging.info(f"n={n:2d}, m={m:4d}, d={digits:7d}, time={tend-tstart:6.1f}, t={str(start):20s}.")
        tstart = time.perf_counter()
    return (0,0)

def find_smallest_positive_solution(p: Point, n: int, maxdigits: int) -> Tuple[int, int]:
    d_best = maxdigits
    m_best = 0
    # Search through each torsion point
    for t in torsions_points(n):
        logging.info(f"n={n:2d}, p={str(p):20s}, t={str(t):20s}")
        (m,digits) = find_positive_solution(t, p, n, d_best)
        if m>0:
            if digits <= d_best:
                d_best = digits
                m_best = m
    if d_best > maxdigits:
        return (0, 0)
    return (m_best, d_best)

import ray # type: ignore
@ray.remote
def run_n(n: int, depth: int, maxdigits: int) -> Tuple[int, Optional[Point], int, int]:
    logging.basicConfig(filename='output.log', level=logging.DEBUG)

    # Verify the torsion points satisfy equation (4)
    for p in torsions_points(n):
        if p is not None:
            assert Equation4(n).eval(p.s) == p.t**2

    # Find a small solution to start from
    tstart = time.perf_counter()
    p = find_a_small_solution(n, depth)
    tend = time.perf_counter()
    logging.info(f"n={n:2d}, p={str(p):20s}, time={tend-tstart:6.1f}")
    if p is None:
        return (n,None,0,0)

    (m,d) = find_smallest_positive_solution(p, n, maxdigits)
    return (n,p,m,d)

import time
def run(nmax: int, depth: int, maxdigits: int) -> None:
    print(f"nmax={nmax}, depth={depth}, maxdigits={maxdigits}")
    tstart = time.perf_counter()
    results = ray.get([run_n.remote(n,depth,maxdigits) for n in reversed(range(4,nmax+1,2))],timeout=360000) # Timeout = 100 hours
    tend = time.perf_counter()

    attempt = 0
    found = 0
    for (n,p,m,d) in reversed(results):
        if p is not None:
            (x,y,z) = sort_xyz(*calc_xyz(*calc_xy(*calc_uv(p.s, p.t, n))))
            print(f"n={n:3d}, s={str(p.s):14s}, t={str(p.t):14s}, x={x:9d}, y={y:9d}, z={z:9d}",end='')
            attempt += 1
            if m:
                found += 1
                print(f", m={m:4d}, d={d:6d}")
            else:
                print()

    print()
    print(f"Time taken: {(tend-tstart)/60:7.1f} minutes.")
    print(f"Found non-torsion points on {attempt} curves.")
    print(f"Found positive solutions on {found} curves.")

ray.init()
run(nmax=200, depth=170, maxdigits=420000)
ray.shutdown()

