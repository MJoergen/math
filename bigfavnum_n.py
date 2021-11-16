#!/usr/bin/env python3
# vim: tabstop=4 shiftwidth=4 expandtab

# References:
# https://www.youtube.com/watch?v=Ct3lCfgJV_A
# https://www.quora.com/How-do-you-find-the-positive-integer-solutions-to-frac-x-y+z-+-frac-y-z+x-+-frac-z-x+y-4
# https://ami.uni-eszterhazy.hu/uploads/papers/finalpdf/AMI_43_from29to41.pdf

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
from dataclasses import dataclass

@dataclass
class Equation1:
    x: Fraction
    y: Fraction
    z: Fraction

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

@dataclass
class Equation2:
    a: Fraction
    b: Fraction
    c: Fraction
    d: Fraction

    def __init__(self, y: Fraction, n: Fraction):
        self.a = 1
        self.b = -(n-1)*(y+1)
        self.c = -((n-1)*y*y+(2*n-3)*y+(n-1))
        self.d = y*y*y-(n-1)*y*y-(n-1)*y+1

    # This function calculates the left-hand-side of equation (2)
    def eval(self, x):
        return (((self.a*x+self.b)*x+self.c)*x+self.d)

# Convert from rational (x,y) to integer (x,y,z) solution
def calc_xyz(x: Fraction, y: Fraction) -> (int, int, int):
    assert x.denominator == y.denominator
    return (x.numerator, y.numerator, y.denominator)

# Verify trivial solutions (for various n values)
assert Equation2(-1, 1234).eval(-1) == 0
assert Equation2( 0, 2345).eval(-1) == 0
assert Equation2( 1, 3456).eval(-1) == 0

# Verify known solutions for n=4.
assert Equation2(-4, 4).eval(-11) == 0
assert Equation2(-11, 4).eval(-4) == 0
assert Equation2(-Fraction(1,4), 4).eval(Fraction(11,4)) == 0
assert Equation2(Fraction(11,4), 4).eval(-Fraction(1,4)) == 0
assert Equation2(-Fraction(1,11), 4).eval(Fraction(4,11)) == 0
assert Equation2(Fraction(4,11), 4).eval(-Fraction(1,11)) == 0

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

@dataclass
class Equation3:
    a: Fraction
    b: Fraction
    c: Fraction
    d: Fraction
    e: Fraction
    f: Fraction

    def __init__(self, n: Fraction):
        self.a = 2*n-4
        self.b = 2*n-1
        self.c = -1
        self.d = 2*n+4
        self.e = -1

    # This function calculates the left-hand-side of equation (3)
    def eval(self, u):
        return (u+1)*((self.a*u+self.b)*u+self.c)/(self.d*u+self.e)

# Convert from (u,v) to (x,y) solution
def calc_xy(u: Fraction, v: Fraction) -> (Fraction, Fraction):
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

@dataclass
class Equation4:
    g: Fraction
    h: Fraction

    def __init__(self, n: Fraction):
        self.g = 4*n*n+12*n-3
        self.h = 32*(n+3)

    # This function calculates the left-hand-side of equation (4)
    def eval(self, s):
        return ((s+self.g)*s+self.h)*s

# Convert from (s,t) to (u,v) solution
def calc_uv(s: Fraction, t: Fraction, n: int) -> (Fraction, Fraction):
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
def farey_sequence(n: int) -> Fraction:
    (a, b, c, d) = (0, 1, 1, n)
    yield Fraction(a,b)
    while c <= n:
        k = (n+b) // d
        (a, b, c, d) = (c, d, k*c-a, k*d-b)
        yield Fraction(a,b)

import gmpy2
def is_square(f: Fraction) -> bool:
    return gmpy2.is_square(f.numerator) and gmpy2.is_square(f.denominator)
def isqrt(f: Fraction) -> bool:
    return Fraction(int(gmpy2.isqrt(f.numerator)), int(gmpy2.isqrt(f.denominator)))


# We introduce an additional helper classes
@dataclass
class Point:
    s: Fraction
    t: Fraction

    def __lt__(self, other):
        return max(self.s.denominator, self.t.denominator) < max(other.s.denominator, other.t.denominator)

# This simply searches all the "simple" rational numbers s between
# -4n(n+3) and 0, inserts into equation (4), and checks whether the
# right hand side evaluates to a square of a rational. If so,
# we've found a solution.
def find_small_solutions(n: int, depth: int) -> Point:
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


@dataclass
class Line:
    a: Fraction
    b: Fraction

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
def calc_sequence(p: Point, t: Point, n: int) -> Point:
    point = t
    m=0
    while True:
        assert Equation4(n).eval(point.s) == point.t**2
        yield (m,point)
        point = add_point(point, p, n)
        m += 1

# This finds the first positive solution to equation (1)
def find_positive_solution(p: Point, t: Point, n: int, depth: int) -> (int, int, int, int, int):
    for (m,p) in calc_sequence(p, t, n):
        (x,y,z) = calc_xyz(*calc_xy(*calc_uv(p.s, p.t, n)))
        if m>=depth:
            return (n,0,0,0,0)
        if x>0 and y>0:
            assert Equation1(x,y,z).eval() == n
            return (n,m,x,y,z)

def find_smallest_positive_solution(p: Point, n: int, depth: int) -> (int, int, int):
    # Define the torsion points
    t2  = Point(Fraction(0), Fraction(0))
    t3p = Point(Fraction(4), Fraction(4*(2*n+5)))
    t3n = Point(Fraction(4), Fraction(-4*(2*n+5)))
    t6p = Point(Fraction(8*(n+3)), Fraction(8*(n+3)*(2*n+5)))
    t6n = Point(Fraction(8*(n+3)), Fraction(-8*(n+3)*(2*n+5)))

    d_best = None
    m_best = None
    # Search through each torsion point
    for t in (t2,t3p,t3n,t6p,t6n):
        # Verify the torsion points satisfy equation (4)
        assert Equation4(n).eval(t.s) == t.t**2
        (n,m,x,y,z) = find_positive_solution(p, t, n, depth)
        if m>0:
            assert Equation1(x,y,z).eval() == n
            digits = max(len(str(x)), len(str(y)), len(str(z)))
            if d_best == None or digits < d_best:
                d_best = digits
                m_best = m
    return (n, m_best, d_best)


for n in range(4,201,2):
    # Find a small solution
    sols = sorted(find_small_solutions(n, depth=800))
    if len(sols) > 0:
        print("n=%2d"%(n),end='',flush=True)
        (n,m,d) = find_smallest_positive_solution(sols[0], n, depth=140)
        if d:
            print(", m=%3d, d=%7d"%(m,d))
        else:
            print()


