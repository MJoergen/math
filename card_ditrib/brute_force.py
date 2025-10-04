#!/usr/bin/env python3

# ./brute_force.py | sort -n -r | uniq -c

# Calculate all possible distributions of the four suits in a bridge hand.
# Expected number of solutions is B(NUM_CARDS+3,3).

NUM_CARDS = 13
res = 0
def extended():
    global res
    for a in range(NUM_CARDS+1):
        for b in range(a, NUM_CARDS+1):
            for c in range(b, NUM_CARDS+1):
                l = [a, b-a, c-b, NUM_CARDS-c]
                res += 1
                print(sorted(l,reverse=True))

extended()
print(res)


