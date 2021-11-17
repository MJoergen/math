#!/usr/bin/env python3
# vim: tabstop=4 shiftwidth=4 expandtab

# References:
# https://www.youtube.com/watch?v=Ct3lCfgJV_A
# https://www.quora.com/How-do-you-find-the-positive-integer-solutions-to-frac-x-y+z-+-frac-y-z+x-+-frac-z-x+y-4
# https://ami.uni-eszterhazy.hu/uploads/papers/finalpdf/AMI_43_from29to41.pdf

# Output generated:
# t=    2.0, n=  4, m=  9, d=     81
# t=    4.0, n=  6, m= 11, d=    134
# t=    8.1, n= 10, m= 13, d=    190
# t=   27.3, n= 12, m= 35, d=   2707
# t=   29.7, n= 14, m= 47, d=   1876
# t=   33.2, n= 16, m= 11, d=    414
# t=   44.6, n= 18, m= 49, d=  10323
# t=  114.5, n= 24, m=107, d=  33644
# t=  270.5, n= 28, m=121, d=  81853
# t=  928.6, n= 32, m= 65, d=  14836
# t= 1161.9, n= 34, m= 11, d=    302
# t= 1244.0, n= 38
# t= 1674.5, n= 60, m= 61, d=   9188
# t= 1776.0, n= 82
# t= 2156.0, n= 92
# t= 2355.7, n=102
# t= 2743.8, n=114, m=  7, d=    136
# t= 2869.5, n=144
# t= 3119.3, n=146
# t= 3369.7, n=160
# t= 3646.4, n=162
# t= 3883.8, n=182

# t=   12, n=  4, s=         -4, t=         28, x=   -11, y=    -4, z=     1
# t=   25, n=  6, s=         -8, t=        104, x=    23, y=    -3, z=     7
# t=   52, n= 10, s=         -1, t=         10, x=   -23, y=   -19, z=    16
# t=   65, n= 12, s=       -216, t=       4824, x=   215, y=  -187, z=   247
# t=   77, n= 14, s=        -17, t=        510, x=    13, y=    -7, z=     8
# t=   90, n= 16, s=       -676, t=      15652, x=  2060, y= -1853, z=  3023
# t=  103, n= 18, s=    -2888/9, t=  298376/27, x= 38947, y=-35647, z= 42753
# t=  143, n= 24, s=      -1764, t=      50652, x=   731, y=  -676, z=  1271
# t=  169, n= 28, s= -167648/49, t=8072896/343, x= 37627, y=-27477, z=283577
# t=  195, n= 32, s=      -1620, t=      86580, x=  2212, y= -2117, z=  2747
# t=  208, n= 34, s=      -1184, t=      73408, x=   253, y=  -243, z=   287
# t=  235, n= 38, s=      -3872, t=     187968, x=  8007, y= -7657, z= 12893
# t=  300, n= 48, s=    -864/49, t= 595008/343, x= 30875, y=-18709, z= 19369
# t=  381, n= 60, s=         -9, t=       1098, x=   179, y=   -65, z=    68
# t=  527, n= 82, s=     -21160, t=    1734200, x=  3377, y= -3293, z=  6835
# t=  593, n= 92, s=      -7448, t=    1235304, x=   303, y=  -299, z=   341
# t=  661, n=102, s=       -945, t=     193410, x=  1859, y= -1825, z=  1864
# t=  741, n=114, s=      -4212, t=     933660, x=  1003, y=  -992, z=  1043
# t=  942, n=144, s=       -756, t=     218988, x=  1315, y= -1292, z=  1307
# t=  955, n=146, s=     -43061, t=    9027612, x=   205, y=  -203, z=   288
# t= 1048, n=160, s=     -32600, t=    8730280, x=   517, y=  -513, z=   623
# t= 1061, n=162, s=     -85536, t=   12507264, x=   145, y=  -143, z=   323
# t= 1088, n=166, s=      -5096, t=    1667848, x= 16099, y=-15975, z= 16451
# t= 1197, n=182, s=      -5408, t=    1944384, x=  1983, y= -1969, z=  2021

# nmax=200, depth=4000, maxdigits=200
# t=   51, n=  4, s=         -4, t=            28, x=   -11, y=    -4, z=     1, m=  9, d=     81
# t=  101, n=  6, s=         -8, t=           104, x=    23, y=    -3, z=     7, m= 11, d=    134
# t=  203, n= 10, s=         -1, t=            10, x=   -23, y=   -19, z=    16, m= 13, d=    190
# t=  254, n= 12, s=       -216, t=          4824, x=   215, y=  -187, z=   247
# t=  306, n= 14, s=        -17, t=           510, x=    13, y=    -7, z=     8
# t=  358, n= 16, s=       -676, t=         15652, x=  2060, y= -1853, z=  3023
# t=  409, n= 18, s=    -2888/9, t=     298376/27, x= 38947, y=-35647, z= 42753
# t=  563, n= 24, s=      -1764, t=         50652, x=   731, y=  -676, z=  1271
# t=  665, n= 28, s= -167648/49, t=   8072896/343, x= 37627, y=-27477, z=283577
# t=  767, n= 32, s=      -1620, t=         86580, x=  2212, y= -2117, z=  2747
# t=  819, n= 34, s=      -1184, t=         73408, x=   253, y=  -243, z=   287
# t=  921, n= 38, s=      -3872, t=        187968, x=  8007, y= -7657, z= 12893
# t= 1126, n= 46, s=      -7396, t=        297388, x= 38147, y=-36200, z= 88703
# t= 1177, n= 48, s=    -864/49, t=    595008/343, x= 30875, y=-18709, z= 19369
# t= 1485, n= 60, s=         -9, t=          1098, x=   179, y=   -65, z=    68
# t= 2049, n= 82, s=     -21160, t=       1734200, x=  3377, y= -3293, z=  6835
# t= 2306, n= 92, s=      -7448, t=       1235304, x=   303, y=  -299, z=   341
# t= 2563, n=102, s=       -945, t=        193410, x=  1859, y= -1825, z=  1864
# t= 2872, n=114, s=      -4212, t=        933660, x=  1003, y=  -992, z=  1043, m=  7, d=    136
# t= 3644, n=144, s=       -756, t=        218988, x=  1315, y= -1292, z=  1307
# t= 3696, n=146, s=     -43061, t=       9027612, x=   205, y=  -203, z=   288
# t= 4005, n=158, s=-2241764/25, t=1231868316/125, x=  3007, y= -2952, z=  8675
# t= 4057, n=160, s=     -32600, t=       8730280, x=   517, y=  -513, z=   623
# t= 4108, n=162, s=     -85536, t=      12507264, x=   145, y=  -143, z=   323
# t= 4211, n=166, s=      -5096, t=       1667848, x= 16099, y=-15975, z= 16451
# t= 4622, n=182, s=       -392, t=        143640, x=  2021, y= -1969, z=  1983
# t= 4725, n=186, s=    -133956, t=      10929492, x=153680, y=-149917, z=699527
# t= 5084, n=200, s=     -53816, t=      17733240, x=  7059, y= -7015, z=  8627



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


## PART 5 - SEARCHING FOR SMALL SOLUTIONS

# We are finally ready to tackle the problem of finding more solutions.
# We start by doing a brute force search for small rational solutions
# to equation (4).
# We see from the previous analysis that the solutions of interest have negative s.
# Equation (4) is positive when s is larger than -(4n^2+12n-3). Since n+3 is a common
# factor in the above equations, I choose to consider the interval from -4n(n+3) to 0.

# We start by generating a sequence of fractions in [0, 1] using a Farey sequence
# https://en.wikipedia.org/wiki/Farey_sequence
def farey_sequence(n: int) -> Iterator[Fraction]:
    (a, b, c, d) = (0, 1, 1, n)
    yield Fraction(a,b)
    while c <= n:
        k = (n+b) // d
        (a, b, c, d) = (c, d, k*c-a, k*d-b)
        yield Fraction(a,b)

import gmpy2
def is_square(f: Fraction) -> bool:
    return gmpy2.is_square(f.numerator) and gmpy2.is_square(f.denominator)
def isqrt(f: Fraction) -> Fraction:
    return Fraction(int(gmpy2.isqrt(f.numerator)), int(gmpy2.isqrt(f.denominator)))


# We introduce an additional helper classes
class Point:
    s: Fraction
    t: Fraction

    def __init__(self, s, t) -> None:
        self.s = s
        self.t = t

    def __lt__(self, other):
        return max(abs(self.s.denominator), abs(self.t.denominator)) < max(abs(other.s.denominator), abs(other.t.denominator))

# This simply searches all the "simple" rational numbers s between
# -4n(n+3) and 0, inserts into equation (4), and checks whether the
# right hand side evaluates to a square of a rational. If so,
# we've found a solution.
def find_small_solutions(n: int, depth: int) -> Iterator[Point]:
    factor = 4*n*(n+3)
    for s1 in farey_sequence(depth):
        s = -s1*factor
        t2 = Equation4(n).eval(s)
        if t2 >=0 and is_square(t2):
            t = isqrt(t2)
            if s != 0 and s != 4 and s != 8*(n+3):
                yield Point(s,t)


## PART 6 - GENERATING A FAMILY OF SOLUTIONS

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

class Line:
    a: Fraction
    b: Fraction

    def __init__(self, a, b) -> None:
        self.a = a
        self.b = b

    def eval(self, s) -> Fraction:
        return self.a*s+self.b

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
def add_point(p1: Point, p2: Point, n: int) -> Point:
    if p1==p2:
        return new_point_tangent(p1, n)
    else:
        return new_point_secant(p1, p2, n)


# This is the main algorithm, stepping through the points indefinitely
# This calculates the sequence m*p+t, for m=0,1,2,...
def calc_sequence(p: Point, t: Point, n: int) -> Iterator[Tuple[int, Point]]:
    point = t
    m=0
    while True:
        assert Equation4(n).eval(point.s) == point.t**2
        yield (m,point)
        point = add_point(point, p, n)
        m += 1

# This finds the first positive solution to equation (1)
def find_positive_solution(p: Point, t: Point, n: int, maxdigits: int) -> Tuple[int, int, int, int, int]:
    for (m,p) in calc_sequence(p, t, n):
        (x,y,z) = calc_xyz(*calc_xy(*calc_uv(p.s, p.t, n)))
        digits = max(len(str(x)), len(str(y)), len(str(z)))
        if digits>maxdigits:
            break
        if x>0 and y>0:
            assert Equation1(x,y,z).eval() == n
            return (n,m,x,y,z)
    return (n,0,0,0,0)

def find_smallest_positive_solution(p: Point, n: int, maxdigits: int) -> Tuple[int, int, int]:
    # Define the torsion points
    t2  = Point(Fraction(0), Fraction(0))
    t3p = Point(Fraction(4), Fraction(4*(2*n+5)))
    t3n = Point(Fraction(4), Fraction(-4*(2*n+5)))
    t6p = Point(Fraction(8*(n+3)), Fraction(8*(n+3)*(2*n+5)))
    t6n = Point(Fraction(8*(n+3)), Fraction(-8*(n+3)*(2*n+5)))

    d_best = maxdigits
    m_best = None
    # Search through each torsion point
    for t in (t2,t3p,t3n,t6p,t6n):
        # Verify the torsion points satisfy equation (4)
        assert Equation4(n).eval(t.s) == t.t**2
        (n,m,x,y,z) = find_positive_solution(p, t, n, d_best)
        if m>0:
            assert Equation1(x,y,z).eval() == n
            digits = max(len(str(x)), len(str(y)), len(str(z)))
            if d_best == None or digits < d_best:
                d_best = digits
                m_best = m
    if d_best == maxdigits:
        return (n, None, None)
    return (n, m_best, d_best)

import time
def run(nmax: int, depth: int, maxdigits: int) -> None:
    print("nmax=%d, depth=%d, maxdigits=%d"%(nmax, depth, maxdigits))
    for n in range(4,nmax+1,2):
        # Find a small solution
        solutions = sorted(find_small_solutions(n, depth))
        if len(solutions) > 0:
            start=solutions[0]
            (x,y,z) = calc_xyz(*calc_xy(*calc_uv(start.s, start.t, n)))
            print("t=%5d, n=%3d, c=%3d, s=%14s, t=%14s, x=%6d, y=%6d, z=%6d"%
                    (int(time.process_time()),n,len(solutions),start.s,start.t,x,y,z),end='',flush=True)
            (n,m,d) = find_smallest_positive_solution(start, n, maxdigits)
            if d:
                print(", m=%3d, d=%7d"%(m,d),flush=True)
            else:
                print(flush=True)

run(nmax = 200, depth = 5000, maxdigits = 200000)

