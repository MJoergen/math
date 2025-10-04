#!/usr/bin/env python3

# Calculate all possible distributions of the four suits in a bridge hand.

# The number of partitions is p(NUM_CARDS+4, 4)
# https://en.wikipedia.org/wiki/Triangle_of_partition_numbers

# Count number of distinct permutations:
# https://codegolf.stackexchange.com/questions/78399/permutations-with-indistinguishable-items
f=lambda l:l==[]or len(l)*f(l[1:])/l.count(l[0])

def factorial(n):
    res = 1
    for f in range(2, n+1):
        res *= f
    return res

def binom(a,b):
    return factorial(a) // factorial(b) // factorial(a-b)

NUM_CARDS=13
n = 0
s = 0
def simplified():
    global n;
    global s;
    for a in range(NUM_CARDS, -1, -1):
        for b in range(a, -1, -1):
            if a+b > NUM_CARDS:
                continue
            for c in range(b, -1, -1):
                if a+b+c > NUM_CARDS:
                    continue
                d = NUM_CARDS - (a+b+c)
                if d <= c:
                    l = [a,b,c,d]
                    com = binom(NUM_CARDS, a) * binom(NUM_CARDS-a, b) * binom(NUM_CARDS-a-b, c) * binom(NUM_CARDS-a-b-c, d)
                    p = com / pow(4, NUM_CARDS) * f(l)
                    print(f"{l}, {int(f(l))}, {com}, {p:.4f}")
                    n += 1
                    s += p

simplified()
print(n,s)


