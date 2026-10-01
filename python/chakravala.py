#!/usr/bin/env python3
# The problem is to find integer solutions
# to a^2 - N*b^2 = 1

import math

# The algorithm is called Chakravala's method and
# works by iteratively finding solutions to the more
# general equation: a^2 - N*b^2 = k
# for some k.
# When k=1 then we are done.
# See: https://en.wikipedia.org/wiki/Chakravala_method

# Helper function
def find_m(n,a,b,k):
    m = 0
    diff = abs(m*m-n)
    last_m = 0
    #print(f"(m.diff)={m, diff})")
    while True:
        m = m + 1
        if ((a+b*m) % abs(k)) == 0:
            new_diff = abs(m*m-n)
            #print(f"(m.diff)={m, new_diff})")
            if new_diff > diff:
                return last_m
            diff = new_diff
            last_m = m

# The main iterative loop starts here
def find_solution(n,a,b,k):
    count=0
    while k != 1:
        #print(f"(a,b,k) = ({a}, {b}, {k})")
        m = find_m(n,a,b,k)
        #print(f"m={m}")
        (a,b,k) = ((a*m+n*b)//abs(k), (a+b*m)//abs(k), (m*m-n)//k)
        assert a*a - n*b*b == k
        count = count+1
    return (a,b,count)

# Choose N=67 as an example
#n=67

max_count = 1
for n in range(1,10000):
    if int(math.sqrt(n)) * int(math.sqrt(n)) == n:
        continue
    # First step is to set b=1 and solve a^2 = N+k
    b = 1
    a = int(math.sqrt(n+1)+0.5) # Rounding to nearest integer ensures |k| is minized.
    k = a*a-n
    assert a*a - n*b*b == k

    (a,b,count) = find_solution(n,a,b,k)
    if count > max_count:
        max_count = count
        print(f"(n,a,b) = ({n}, {a}, {b}) after {count} iterations")
    #print(f"Found the solution: {a}^2 - {n}*{b}^2 = 1")


