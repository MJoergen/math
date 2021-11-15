#!/usr/bin/env python3
# https://www.youtube.com/watch?v=Ct3lCfgJV_A

# This little program attempts to solve the equation
# (1) : x/(y+z) + y/(x+z) + z/(x+y) = 4
# This equation is invariant for all permutations of (x,y,z)

# Since we'll be working with fractions let's import the module
from fractions import Fraction

# This function calculates the left-hand-side of equation (1)
def calc_equation(x: int, y: int, z: int) -> Fraction:
    return Fraction(x,y+z) + Fraction(y,x+z) + Fraction(z,x+y)

# We want positive integer solutions.
# One such solution is (-11, -4, 1).

# Verify the solution (all permutations)
assert calc_equation(-11,  -4,   1) == 4
assert calc_equation(-11,   1,  -4) == 4
assert calc_equation( -4, -11,   1) == 4
assert calc_equation( -4,   1, -11) == 4
assert calc_equation(  1,  -4, -11) == 4
assert calc_equation(  1, -11,  -4) == 4

# Since this is homogenous in x,y,z, we can set z=1. Re-arranging gives:
# x(x+1)(x+y) + y(y+1)(x+y) + (x+1)(y+1) = y(x+1)(y+1)(x+y)
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

    # https://en.wikipedia.org/wiki/Cubic_equation#General_cubic_formula
    def discriminant(self) -> Fraction:
        delta0 = self.b*self.b-3*self.a*self.c
        delta1 = 2*self.b*self.b*self.b-9*self.a*self.b*self.c+27*self.a*self.a*self.d
        return delta1*delta1 - 4*delta0*delta0*delta0

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
    assert calc_equation(x,y,z) == 4 # Verify equation (1) is satisfied
    print("x=%d\ny=%d\nz=%d" % (x, y, z))
    print()

# We now have all the ingredients to calculate a sequence of points starting from (-11, -4).
p1 = Point(Fraction(-11), Fraction(-4))
print_solution(p1)
p2 = new_point_tangent(p1)
print_solution(p2)
pn = p2
for n in range(3, 20):
    pn = new_point_secant(p1, pn)
    print_solution(pn)
    if pn.x > 0 and pn.y > 0: # We've finally found a posive solution
        break

