#!/usr/bin/env python3

# https://en.wikipedia.org/wiki/Triangle_of_partition_numbers

# p(n.k) = p(n-1, k-1) + p(n-k, k)

# p(n,k) = SUM p(n-1-j*k, k-1), j=0..n/k

# p(n,1) = 1
# p(n,2) = n//2
# p(n,3) = (n^2+6)//12
# p(n,4) = (n^3 + 3*n^2 - 9*n*(n % 2) + 32)//144

def p(n,k):
    if n<k:
        return 0
    if k==1:
        return 1
    return p(n-1,k-1) + p(n-k,k)

print("k=2")
for n in range(1, 30):
    print(n, p(n,2), n//2)

print("k=3")
for n in range(1, 100):
    print(n, p(n,3), (n*n+6)//12)

print("k=4")
for n in range(1, 100, 1):
    print(n, p(n,4), p(n,4) - (n*n*n + 3*n*n - 9*n*(n % 2) + 32)//144)

