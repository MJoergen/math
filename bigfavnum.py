#!/usr/bin/env python3
# https://www.youtube.com/watch?v=Ct3lCfgJV_A

# This little program attempts to solve the equation
# (1) : x/(y+z) + y/(x+z) + z/(x+y) = 4
# We want positive integer solutions.
# This equation is invariant for all permutations of (x,y,z)

# Since we'll be working with fractions let's import the module
from fractions import Fraction

# This function calculates the left-hand-side of equation (1)
def calc_equation(x: int, y: int, z: int) -> Fraction:
    return Fraction(x,y+z) + Fraction(y,x+z) + Fraction(z,x+y)

# One such solution is (-11, -4, 1).

# Verify the solution (all permutations)
assert calc_equation(-11,  -4,   1) == 4
assert calc_equation(-11,   1,  -4) == 4
assert calc_equation( -4, -11,   1) == 4
assert calc_equation( -4,   1, -11) == 4
assert calc_equation(  1,  -4, -11) == 4
assert calc_equation(  1, -11,  -4) == 4

# Since this is homogenous in x,y,z, we can set z=1. Re-arranging gives:
# x(x+1)(x+y) + y(y+1)(x+y) + (x+1)(y+1) = 4(x+1)(y+1)(x+y)
# Here we want positive rational solutions.
# A new solution (1, -1) appears.
# Multiplying out the above we get:
# (2) : x^3 - 3(y+1)x^2 - x(3y^2+5y+3) + y^3-3y^2-3y+1 = 0
# With the solutions (-11, -4) and (1, -1) as mentioned before.
# With the permutations, a solution (x,y) implies the following
# other solutions: (y,x), (1/x, y/x), (y/x, 1/x), (1/y, x/y), and (x/y, 1/y).

# From now on we work with rational points (x,y)
from dataclasses import dataclass
@dataclass
class Point:
    x: Fraction
    y: Fraction

# We start with a helper function to return a list of factors of any integer
def factors(n):
    return set(
        factor for i in range(1, int(n**0.5) + 1) if n % i == 0
        for factor in (i, n//i)
    )

# This is a general cubic polynomial
@dataclass
class Curve:
    a: Fraction
    b: Fraction
    c: Fraction
    d: Fraction

    # Initialize using equation (2) above
    def __init__(self, y: Fraction):
        self.a = 1
        self.b = -3*(y+1)
        self.c = -(3*y*y+5*y+3)
        self.d = y*y*y-3*y*y-3*y+1

    # Evaluate at an arbitrary x value
    def eval(self, x: Fraction) -> Fraction:
        return (((self.a*x+self.b)*x+self.c)*x+self.d)

    # This function applies the rational root theorem
    # and returns all rational solutions to the cubic equation (2)
    def rational_solutions(self) -> Fraction:
        assert self.a == 1 # We only handle this special case
        list_n = factors(abs(self.d.numerator))
        list_d = factors(abs(self.d.denominator))
        for n in list_n:
            for d in list_d:
                if self.eval(Fraction(n,d)) == 0:
                    yield Fraction(n,d)
                if self.eval(-Fraction(n,d)) == 0:
                    yield -Fraction(n,d)


# This function calculates the value of the left hand side of equation (2)
def calc_curve(p: Point) -> Fraction:
    return Curve(p.y).eval(p.x)

# Verify the known solutions
assert calc_curve(Point(-11, -4)) == 0
assert calc_curve(Point(-4, -11)) == 0
assert calc_curve(Point(Fraction(4,11), -Fraction(1,11))) == 0
assert calc_curve(Point(-Fraction(1,11), Fraction(4,11))) == 0
assert calc_curve(Point(Fraction(11,4), -Fraction(1,4))) == 0
assert calc_curve(Point(-Fraction(1,4),  Fraction(11,4))) == 0

assert calc_curve(Point(1, -1)) == 0
assert calc_curve(Point(-1, 1)) == 0

# If we have a solution (x1,y1) to equation (2) then
# the slope of the curve can be calculated as follows
# a = (3x^2 - 6xy - 3y^2 - 6x - 5y - 3)/(3x^2 + 6xy - 3y^2 + 5x + 6y + 3)

# This function calculates the slope of the curve at a given point
def calc_slope(p: Point) -> Fraction:
    return (3*p.x*p.x - 6*p.x*p.y - 3*p.y*p.y - 6*p.x - 5*p.y - 3)/ \
           (3*p.x*p.x + 6*p.x*p.y - 3*p.y*p.y + 5*p.x + 6*p.y + 3)

# Intersection with a line y=ax+b leads to a cubic equation.

# Since we're working with lines, let's introduce a class for that.
@dataclass
class Line:
    a: Fraction
    b: Fraction

# Inserting the line equation y=ax+b into equation (2) leads
# to a cubic equation in x, where the sum of roots becomes
# x1+x2+x3 = (3a^2-3a^2b+6ab+5a+3b+3)/(a^3-3a^2-3a+1)
# In other words, any line intersects the equation (2) in
# three points satisfying the above.

def sum_roots(l: Line) -> Fraction:
    return (3*l.a*l.a - 3*l.a*l.a*l.b + 6*l.a*l.b + 5*l.a + 3*l.b + 3)/ \
           (l.a*l.a*l.a - 3*l.a*l.a - 3*l.a + 1)

# If we have a single point satisfying (2) then the tangent will
# intersect the curve in a second point easily calculated as follows:
def calc_tangent(p: Point) -> Line:
    a = calc_slope(p)
    b = p.y - a*p.x
    return Line(a,b)

def new_point_tangent(p1: Point) -> Point:
    l = calc_tangent(p1)
    s = sum_roots(l)
    x3 = s - p1.x - p1.x # Subtract twice, because a tangent is a double root
    y3 = l.a*x3 + l.b
    return Point(y3,x3) # Swap x and y

# If instead we have two existing solutions (x1,y1) and (x2,y2)
# then a third solution can be found be first calculating the line
# through the points by a=(y2-y1)/(x2-x1) and b=y1-a*x1,
# and then using the above sum-of-roots to calculate the new solution x3.

def calc_secant(p1: Point, p2: Point) -> Line:
    a = (p2.y-p1.y)/(p2.x-p1.x)
    b = p1.y - a*p1.x
    return Line(a,b)

def new_point_secant(p1: Point, p2: Point) -> Point:
    l = calc_secant(p1, p2)
    s = sum_roots(l)
    x3 = s - p1.x - p2.x
    y3 = l.a*x3 + l.b
    return Point(y3,x3) # Swap x and y

# We need to convert from a rational solution of (2) to an integer solution of (1).
# We do this by multiplying both x and y by their common denominator.
def print_solution(p: Point):
    assert p.x.denominator == p.y.denominator
    assert calc_curve(p) == 0 # Verify equation (2) is satisfied
    (x,y,z) = (Fraction(p.x.numerator), Fraction(p.y.numerator), Fraction(p.x.denominator))
    if x+y != 0 and x+z != 0 and y+z != 0:
        assert calc_equation(x,y,z) == 4 # Verify equation (1) is satisfied
        print("x=%d\ny=%d\nz=%d" % (x, y, z))
        print()

# This is the main algorithm, stepping through the points indefinitely
def calc_sequence(p: Point) -> Point:
    first_point = p
    yield p
    p = new_point_tangent(first_point)
    yield p
    while True:
        p = new_point_secant(first_point, p)
        yield p

# We now have all the ingredients to calculate a sequence of points starting from (-11, -4).
print("Searching for solutions using method A:")
for p in calc_sequence(Point(Fraction(-11), Fraction(-4))):
    print_solution(p)
    if p.x > 0 and p.y > 0:
        break

# This second part searches for (other) small solutions

# We start by generating a sequence of fractions in [-1, 1] using a Farey sequence
# https://en.wikipedia.org/wiki/Farey_sequence
def farey_sequence(n: int) -> Fraction:
    (a, b, c, d) = (0, 1, 1, n)
    yield Fraction(a,b)
    while c <= n:
        k = (n+b) // d
        (a, b, c, d) = (c, d, k*c-a, k*d-b)
        yield Fraction(a,b)
        yield -Fraction(a,b)

# For each y-value we search for any rational solutions to equation (2)
print("Searching for solutions using method B:")
for y in farey_sequence(9):
    curve = Curve(y)
    for x in curve.rational_solutions():
        p = Point(x,y)
        print_solution(p)

# An alternate solution approach is to substitute x=u+v and y=u-v into equation (2)
# This gives after some algebra:
# 4u^3 + 11u^2 + 6(1-2v^2)u + v^2-1 = 0
# which can be re-arranged to:
# v^2 = (u+1)*(4*u*u+7*u-1)/(12u-1)
# So we just search various values for u, and determine whether v is a pure square

import gmpy2
def is_square(f: Fraction) -> bool:
    return gmpy2.is_square(f.numerator) and gmpy2.is_square(f.denominator)
def isqrt(f: Fraction) -> bool:
    return Fraction(int(gmpy2.isqrt(f.numerator)), int(gmpy2.isqrt(f.denominator)))

print("Searching for solutions using method C:")
for u in farey_sequence(90):
    if 12*u-1 == 0:
        continue
    v2 = (u+1)*(4*u*u+7*u-1)/(12*u-1)
    if v2 >=0 and is_square(v2):
        v = isqrt(v2)
        p = Point(u+v, u-v)
        print_solution(p)

def get_solution_from_ab(a: Fraction, b: Fraction) -> Point:
    (u,v) = ((a-56)/(12*a+56), -b/(12*a+56))
    p=Point(u+v, u-v)
    return p

# Yet another substitution simplifies further.
# Setting A = -56(u+1)/(12u-1) and B = 728v/(12u-1) gives
# B^2 = A^3+109A^2+224A
# Then u = (A-56)/(12A+56) and v = -B/(12A+56).
print("Searching for solutions using method D:")
for a1 in farey_sequence(90):
    a = a1*56
    b2 = ((a+109)*a+224)*a
    if b2 >=0 and is_square(b2):
        b = isqrt(b2)
        p = get_solution_from_ab(a,b)
        print_solution(p)

# The solution (A,B) = (0, 0) corresponds to (u,v) = (-1, 0), i.e.
# the point (x,y) = (-1, -1)
# The solution (A,B) = (4, 52) corresponds to (u,v) = (-1/2, -1/2), i.e.
# the point (x,y) = (-1, 0)
# The solution (A,B) = (56, 728) corresponds to (u,v) = (0, -1), i.e.
# the point (x,y) = (-1, 1)
# The solution (A,B) = (-4, 28) corresponds to (u,v) = (-15/2, -7/2), i.e.
# the point (x,y) = (-11, -4)

assert calc_curve(get_solution_from_ab(Fraction(0), Fraction(0))) == 0
assert calc_curve(get_solution_from_ab(Fraction(4), Fraction(52))) == 0
assert calc_curve(get_solution_from_ab(Fraction(56), Fraction(56*13))) == 0
assert calc_curve(get_solution_from_ab(Fraction(-4), Fraction(28))) == 0

