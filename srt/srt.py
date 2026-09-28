#! /usr/bin/env python3

# Bit-exact model of the SRT divider in this directory.
#
# This models srt.vhd (with srt_core.vhd, pla.vhd, normalizer.vhd, and
# shifter.vhd) using integers, so the quotient is exactly the same as the one
# calculated by the VHDL. The quotient digit table is built the same way as in
# pla.vhd, and the partial remainder is kept in carry-save form, like in
# srt_core.vhd. Alternatively, the Pentium's table can be used (pla_pentium.vhd),
# which reproduces the FDIV bug, and the partial remainder can be calculated
# exactly instead (--exact).
#
# It can also check every entry of the table: It verifies that the chosen
# quotient digit keeps the partial remainder within bounds, for all values of n
# and d that map to that entry. Entries can be removed from the table (like
# the missing entries in the Pentium), to see which table entries then fail,
# and to search for divisions that give a wrong result.
#
# Usage:
#   ./srt.py                   Check the table, and test many divisions.
#   ./srt.py --exact           The same, with an exact partial remainder
#                              instead of carry-save.
#   ./srt.py N D [--trace]     Calculate N/D, optionally showing each iteration.
#   ./srt.py --remove 2.5:1.5  Remove the table entry for n=2.5, d=1.5, and
#                              search for divisions that give a wrong result.
#                              Use --remove=-2.5:1.0 for a negative n.
#   ./srt.py --tikz            Print the digit boundaries of the table, for the
#                              diagram in pla.tex.
#   ./srt.py --bounds          Print the range of the partial remainder for each
#                              column of the table.
#   ./srt.py --pla pentium     Use the original Pentium table (with the FDIV
#                              bug) instead. Or --pla pentium_fixed.
#   ./srt.py 4195835 3145727 --pla pentium
#                              Calculate a division that fails on the Pentium.

import argparse
import os
import random
import re
import sys
from fractions import Fraction

G_SIZE = 32                       # The value of G_SIZE used by srt
MAX_INPUT = 2**29 - 1             # Largest input value supported by srt


def to_signed(x, bits):
    return x - (1 << bits) if (x >> (bits - 1)) & 1 else x


# -------------------------------------------------------------------------
# The quotient digit table (pla.vhd)
# -------------------------------------------------------------------------

# Select |q| for the table entry with the top 7 bits n7 of n (as a signed
# integer) and the 4 bits d4 of d after the leading one. This is the function
# get_q in pla.vhd: it rounds n/d to the nearest integer at the centre of the
# region the entry must cover, i.e. at n = n7/8 + 1/8 (two rows, to allow for
# the carry-save estimate) and d = 1 + d4/16 + 1/32. In units of 1/32 these
# are n_v and d_v. Since 2*|n_v| is even and d_v is odd, there are no ties.
def get_q(n7, d4):
    n_v = 4 * n7 + 4
    d_v = 33 + 2 * d4
    if 2 * abs(n_v) < d_v:
        return 0
    elif 2 * abs(n_v) < 3 * d_v:
        return 1
    else:
        return 2


# Read the Pentium's table from pla_pentium.vhd, either the original version
# (with the FDIV bug) or the fixed version. The file has one row for each
# value of n, from 0111.111 down to 1000.000, and each row holds the values of
# |q| for the 16 values of d in both versions.
def pentium_table(fixed):
    path = os.path.join(os.path.dirname(os.path.abspath(__file__)), "pla_pentium.vhd")
    with open(path) as f:
        rows = re.findall(r'\("([012]{16})", "([012]{16})"\),? *-- ([01]{4})\.([01]{3})', f.read())
    assert len(rows) == 128, "pla_pentium.vhd must have 128 rows"
    table = [None] * 2048
    for original, fixed_row, n_int, n_frac in rows:
        n = int(n_int + n_frac, 2)
        for col, digit in enumerate(fixed_row if fixed else original):
            table[(n << 4) | col] = int(digit)
    assert None not in table, "pla_pentium.vhd must have one row for each value of n"
    return table


# The table index is the top 7 bits of n followed by the 4 bits of d just
# after the leading "0001". Each entry stores |q|. The table is either the one
# from pla.vhd ("srt"), or one of the Pentium's ("pentium", "pentium_fixed").
def build_table(remove=(), pla="srt"):
    if pla == "srt":
        table = [get_q(to_signed(i >> 4, 7), i & 15) for i in range(2048)]
    else:
        table = pentium_table(fixed=(pla == "pentium_fixed"))
    for i in remove:
        table[i] = 0                # Like the missing entries in the Pentium
    return table


# Return the table index for the real values n and d
def table_index(n, d):
    n7 = int(Fraction(n) * 8 // 1) & 0x7F
    d4 = int((Fraction(d) - 1) * 16 // 1)
    assert 0 <= d4 < 16, "d must be in the range [1, 2)"
    return (n7 << 4) | d4


# Return the range of n and d that map to a table index, as
# (n_lo, n_hi, d_lo, d_hi), where n_lo <= n < n_hi and d_lo <= d < d_hi.
def cell_bounds(idx):
    n_lo = Fraction(to_signed(idx >> 4, 7), 8)
    d_lo = 1 + Fraction(idx & 15, 16)
    return n_lo, n_lo + Fraction(1, 8), d_lo, d_lo + Fraction(1, 16)


# Look up the quotient digit for the G-bit values n and d
def pla(n, d, table, g=G_SIZE):
    idx = ((n >> (g - 7)) << 4) | ((d >> (g - 8)) & 15)
    q = table[idx]
    return -q if (n >> (g - 1)) & 1 else q


# -------------------------------------------------------------------------
# The divider (srt_core.vhd)
# -------------------------------------------------------------------------

# Divide the normalized g-bit values n and d, and return the quotient with 2
# integer bits and 2*g+2 fractional bits. If trace is a list, then the partial
# remainder, the value of n used for the table lookup, and the quotient digit
# of each iteration are appended to it.
#
# With carry_save, the partial remainder is kept in carry-save form, like in
# srt_core.vhd and in the Pentium: n = s + c. Then n - q*d is calculated with a
# carry-save adder, without propagating any carries. A positive q*d is subtracted by adding its
# complement, and adding the 1 as the lowest bit of the carries. For the table
# lookup, only the top 7 bits of s and c are added. This ignores the carries
# from the lower bits, so the lookup can use the table row just below n. With
# the original Pentium table, this very rarely reaches a missing entry.
def srt_core(n, d, table, g=G_SIZE, trace=None, carry_save=True):
    mask = (1 << g) - 1
    s, c = n, 0
    q = 0
    for _ in range(g + 2):
        if carry_save:
            top = ((s >> (g - 7)) + (c >> (g - 7))) & 0x7F
            n_lookup = top << (g - 7)
        else:
            n_lookup = s
        digit = pla(n_lookup, d, table, g)
        if trace is not None:
            trace.append(((s + c) & mask, n_lookup, digit))
        if carry_save:
            if digit > 0:
                y, carry_in = ~(digit * d) & mask, 1
            else:
                y, carry_in = (-digit * d) & mask, 0
            s, c = s ^ c ^ y, (((s & c) | (s & y) | (c & y)) << 1) | carry_in
            s, c = (s << 2) & mask, (c << 2) & mask
        else:
            s = ((s - digit * d) << 2) & mask
        q = 4 * q + digit
    return q & ((1 << (2 * g + 4)) - 1)


# -------------------------------------------------------------------------
# The complete divider (srt.vhd, normalizer.vhd, and shifter.vhd)
# -------------------------------------------------------------------------

# Shift x left so the top nibble is "0001". Return the shifted value and the
# shift amount.
def normalize(x):
    shift = max(32 - x.bit_length() - 3, 0)
    return (x << shift) & 0xFFFFFFFF, shift


# Divide two unsigned integers, and return the quotient with 32 integer bits
# and 32 fractional bits, rounded to nearest.
def srt(n_i, d_i, table, trace=None, carry_save=True):
    if not valid_inputs(n_i, d_i):
        return (1 << 64) - 1                    # Invalid inputs: all ones
    n, nz = normalize(n_i)
    d, dz = normalize(d_i)
    q = srt_core(n, d, table, trace=trace, carry_save=carry_save)
    shifted = q >> (30 + nz - dz)
    return ((shifted + 8) & ((1 << 68) - 1)) >> 4


# The inputs are valid if both are less than 2^29, and d_i is not zero
def valid_inputs(n_i, d_i):
    return n_i <= MAX_INPUT and 0 < d_i <= MAX_INPUT


# The exact quotient, rounded to nearest. There are no ties when d_i < 2^29.
# For invalid inputs, srt returns all ones.
def expected(n_i, d_i):
    if not valid_inputs(n_i, d_i):
        return (1 << 64) - 1
    return ((n_i << 33) + d_i) // (2 * d_i)


# -------------------------------------------------------------------------
# Exhaustive check of the table
# -------------------------------------------------------------------------

# Clip a convex polygon to the half-plane a*n + b*d + c >= 0
def clip(poly, a, b, c):
    out = []
    for i, p in enumerate(poly):
        q = poly[(i + 1) % len(poly)]
        vp = a * p[0] + b * p[1] + c
        vq = a * q[0] + b * q[1] + c
        if vp >= 0:
            out.append(p)
        if (vp >= 0) != (vq >= 0):
            t = vp / (vp - vq)
            out.append((p[0] + t * (q[0] - p[0]), p[1] + t * (q[1] - p[1])))
    return out


# For each table entry, consider all the values of n and d that map to it, and
# that satisfy the invariant of the algorithm: |n/d| < 8/3. Verify that the
# next partial remainder 4*(n - q*d) satisfies the invariant too.
#
# The conditions are linear in n and d, so it is enough to check the corners of
# the region, using exact rational arithmetic. A corner where the condition
# only just fails (with equality) is fine, if it lies on an edge of the region
# that is excluded, e.g. n = n_hi.
#
# This is slightly conservative, since n and d are treated as real numbers,
# and since not all of the region is necessarily reachable.
#
# With carry_save, the entry must also be valid for the row of n above it,
# since with a carry-save partial remainder the table may see n one row too
# low.
#
# Returns the list of failing table indices.
def check_table(table, carry_save=True):
    bad = []
    for idx in range(2048):
        n_lo, n_hi, d_lo, d_hi = cell_bounds(idx)
        if carry_save:
            # The table may see n one row too low, so the entry must also be
            # valid for the row above.
            n_hi += Fraction(1, 8)
        poly = [(n_lo, d_lo), (n_hi, d_lo), (n_hi, d_hi), (n_lo, d_hi)]
        poly = clip(poly, -1, Fraction(8, 3), 0)       # n < 8d/3
        poly = clip(poly, 1, Fraction(8, 3), 0)        # n > -8d/3
        if len(poly) < 3:
            continue                                   # Not reachable

        # The edges of the region that are excluded
        excluded = [lambda n, d: n == n_hi,
                    lambda n, d: d == d_hi,
                    lambda n, d: 3 * n == 8 * d,
                    lambda n, d: 3 * n == -8 * d]

        q = table[idx] if n_lo >= 0 else -table[idx]
        for sign in (1, -1):
            # We need f < 0 everywhere in the region, where
            # f = 3*(+/-next) - 8*d, and next = 4*(n - q*d).
            f = [(3 * sign * 4 * (n - q * d) - 8 * d, (n, d)) for n, d in poly]
            worst = max(v for v, _ in f)
            zeros = [p for v, p in f if v == 0]
            if worst > 0 or (worst == 0 and
                             not any(all(e(*p) for p in zeros) for e in excluded)):
                bad.append(idx)
                break
    return bad


# -------------------------------------------------------------------------
# The range of the partial remainder
# -------------------------------------------------------------------------

# Calculate the range of the partial remainder for a fixed divisor d, which
# selects one column of the table. The divisor does not change during a
# division.
#
# Start with the range of the dividend, i.e. 0 <= n < 2. For each table row
# (n in [row/8, (row+1)/8)) that intersects the current range, the next partial
# remainder 4*(n - q*d) is between the images of the row's two ends. Extend the
# range with these images, until it no longer changes. The result is a range
# that the partial remainder never leaves. The upper limit is never reached.
#
# With carry_save, the table may see n one row too low, so the digit of the
# row below is possible too.
#
# Returns (lo, hi), with lo <= n < hi, or None if the range grows beyond the
# 4 integer bits of n, i.e. the division fails.
def remainder_range(table, col, d, carry_save=True):
    def digit(row):
        q = table[((row & 0x7F) << 4) | col]
        return -q if row < 0 else q

    lo, hi = Fraction(0), Fraction(2)
    while True:
        new_lo, new_hi = lo, hi
        for row in range(-64, 64):
            a = max(Fraction(row, 8), lo)
            b = min(Fraction(row + 1, 8), hi)
            if a < b:
                digits = {digit(row)}
                if carry_save and row > -64:
                    digits.add(digit(row - 1))
                for q in digits:
                    new_lo = min(new_lo, 4 * (a - q * d))
                    new_hi = max(new_hi, 4 * (b - q * d))
        if new_lo < -8 or new_hi > 8:
            return None
        if (new_lo, new_hi) == (lo, hi):
            return lo, hi
        lo, hi = new_lo, new_hi


# Calculate the range of the partial remainder for each column of the table.
# Within a column, the limits are linear in d (as long as the same table rows
# are involved), so the extremes are at the ends of the column. This evaluates
# the ends and 15 points in between. The upper end of the column is not a
# valid divisor, so the limits found there are only approached, never reached.
#
# Returns a list with one entry per column: (lo, lo_reached, hi), or None if
# the partial remainder is not bounded.
def remainder_bounds(table, carry_save=True):
    result = []
    for col in range(16):
        d_lo = 1 + Fraction(col, 16)
        ranges = [remainder_range(table, col, d_lo + Fraction(i, 16 * 16), carry_save)
                  for i in range(17)]
        if None in ranges:
            result.append(None)
            continue
        lo = min(r[0] for r in ranges)
        lo_reached = any(r[0] == lo for r in ranges[:16])     # Not only at the upper end
        hi = max(r[1] for r in ranges)
        result.append((lo, lo_reached, hi))
    return result


def format_bounds(lo, lo_reached, hi):
    return f"{lo} {'<=' if lo_reached else '<'} n < {hi}"


def print_bounds(bounds, per_column):
    if per_column:
        for col, b in enumerate(bounds):
            d_lo = 1 + Fraction(col, 16)
            text = "not bounded" if b is None else format_bounds(*b)
            print(f"  column {col:2d}, d in [{d_lo}, {d_lo + Fraction(1, 16)}): {text}")
    if None in bounds:
        print("Partial remainder: NOT BOUNDED in some columns, i.e. some divisions fail.")
    else:
        lo = min(b[0] for b in bounds)
        lo_reached = any(b[1] for b in bounds if b[0] == lo)
        hi = max(b[2] for b in bounds)
        print(f"Partial remainder: {format_bounds(lo, lo_reached, hi)}.")


# -------------------------------------------------------------------------
# Diagram of the table
# -------------------------------------------------------------------------

# Print the boundaries between the quotient digits in the table as TikZ paths,
# for the diagram in pla.tex. In each column of the table (i.e. range of d),
# the boundary between digit k and k+1 is at the smallest n where the table
# selects a digit larger than k. So each boundary is a staircase.
def print_tikz(table):
    def digit(row, col):                        # n in [row/8, (row+1)/8)
        q = table[((row & 0x7F) << 4) | col]
        return -q if row < 0 else q

    print("% Generated by ./srt.py --tikz. Do not edit.")
    for k in range(-2, 2):
        points = []
        for col in range(16):
            row = min(r for r in range(-64, 64) if digit(r, col) > k)
            points += [(1 + col / 16, row / 8), (1 + (col + 1) / 16, row / 8)]
        path = " -- ".join(f"({d:g},{n:g})" for d, n in points)
        print(f"\\draw[boundary] {path};")


# -------------------------------------------------------------------------
# Search for a division that uses a given table entry
# -------------------------------------------------------------------------

# Some table entries are only used by very few divisions (in the Pentium, about
# one in nine billion), so a random search will not find them. Instead, this
# works backwards: Choose a partial remainder n_next in the table entry, and a
# divisor d. The previous partial remainder must then be n = n_next/4 + q*d,
# for one of the digits q that the table would actually select for (n, d).
# Repeat until n is a valid dividend, i.e. in the range [1, 2).
#
# The values are G-bit integers (i.e. scaled by 2^(G_SIZE-4)), so everything
# is exact. Since the result is normalized already, it can be used directly as
# the inputs of srt. Returns (n_i, d_i), or None if nothing was found.
def find_input(idx, table, max_depth=10, tries=2000, seed=1):
    rng = random.Random(seed)
    g = G_SIZE
    one = 1 << (g - 4)                          # The value 1.0
    mask = (1 << g) - 1
    n_lo, n_hi, d_lo, d_hi = cell_bounds(idx)

    def search(n, d, depth):
        if one <= n < 2 * one:
            return n                            # A valid dividend
        if depth == 0 or n % 4 != 0:
            return None
        for q in range(-2, 3):
            prev = n // 4 + q * d
            if 3 * abs(prev) < 8 * d and pla(prev & mask, d, table) == q:
                found = search(prev, d, depth - 1)
                if found is not None:
                    return found
        return None

    step = 4**max_depth                         # So n can be divided by 4 enough times
    for _ in range(tries):
        d = rng.randrange(int(d_lo * one), int(d_hi * one))
        n = rng.randrange(int(n_lo * one) // step, int(n_hi * one) // step) * step
        if 3 * abs(n) >= 8 * d or not n_lo * one <= n < n_hi * one:
            continue
        found = search(n, d, max_depth)
        if found is not None:
            return found, d
    return None


# -------------------------------------------------------------------------
# Testing
# -------------------------------------------------------------------------

# The edge cases also used in tb_srt.vhd
def edge_cases():
    yield from [(0, 0), (1, 0), (MAX_INPUT, 0), (2**29, 1), (1, 2**29),
                (2**32 - 1, 3), (2**32 - 1, 2**32 - 1), (2**32 - 1, 0),
                (0, 1), (0, 7), (0, MAX_INPUT), (MAX_INPUT, 1), (MAX_INPUT, 3),
                (MAX_INPUT, MAX_INPUT), (MAX_INPUT - 1, MAX_INPUT),
                (1, MAX_INPUT), (123456789, 1000)]
    for i in range(29):
        for j in range(29):
            yield 2**i, 2**j
            yield 2**(i + 1) - 1, 2**j
            yield 2**i, 2**(j + 1) - 1
            yield 2**(i + 1) - 1, 2**(j + 1) - 1


# Compare the model against the exact quotient. If bad_cells is given, then
# the divisors are chosen within the range of one of those table entries, which
# makes it much more likely to find a division that uses them.
def test(table, count, bad_cells=(), max_errors=5, carry_save=True):
    rng = random.Random(1)
    cases = list(dict.fromkeys(edge_cases()))          # Remove duplicates
    for _ in range(count):
        if bad_cells:
            _, _, d_lo, _ = cell_bounds(rng.choice(bad_cells))
            d = (int(d_lo * 16) << 24) + rng.randrange(1 << 24)
            n = rng.randrange(1 << 28, 1 << 29)
            cases.append((n >> rng.randrange(29), d >> rng.randrange(29)))
        else:
            cases.append((rng.randrange(MAX_INPUT + 1), rng.randrange(1, MAX_INPUT + 1)))

    errors = 0
    for n, d in cases:
        got = srt(n, d, table, carry_save=carry_save)
        exp = expected(n, d)
        if got != exp:
            errors += 1
            if errors <= max_errors:
                print(f"  WRONG: {n}/{d}: got 0x{got:016X}, expected 0x{exp:016X}")
    print(f"Tested {len(cases)} divisions: {errors} wrong.")
    return errors


def show_division(n, d, table, trace, carry_save=True):
    steps = []
    q = srt(n, d, table, trace=steps, carry_save=carry_save)
    if trace:
        scale = 2**(G_SIZE - 4)
        for k, (r, r_lookup, digit) in enumerate(steps):
            row = to_signed(r_lookup >> (G_SIZE - 7), 7) / 8
            print(f"  iter {k:2d}: n = {to_signed(r, G_SIZE) / scale:+.8f}, table row {row:+.3f}, q = {digit:+d}")
    exp = expected(n, d)
    note = "" if valid_inputs(n, d) else "  (invalid inputs)"
    print(f"{n}/{d} = 0x{q:016X} = {q / 2**32:.10f}{note}" + ("" if q == exp else f"  WRONG, expected 0x{exp:016X}"))


def main():
    parser = argparse.ArgumentParser(description="Bit-exact model of the SRT divider.")
    parser.add_argument("n", type=int, nargs="?", help="dividend")
    parser.add_argument("d", type=int, nargs="?", help="divisor")
    parser.add_argument("--trace", action="store_true", help="show each iteration")
    parser.add_argument("--remove", action="append", default=[], metavar="N:D",
                        help="remove the table entry containing n=N, d=D")
    parser.add_argument("--count", type=int, default=100000,
                        help="number of random divisions to test (default 100000)")
    parser.add_argument("--tikz", action="store_true",
                        help="print the digit boundaries of the table for pla.tex")
    parser.add_argument("--bounds", action="store_true",
                        help="print the range of the partial remainder for each column")
    parser.add_argument("--pla", choices=["srt", "pentium", "pentium_fixed"], default="srt",
                        help="the quotient digit table: pla.vhd (default), or the Pentium's "
                             "original or fixed table from pla_pentium.vhd")
    parser.add_argument("--exact", action="store_true",
                        help="calculate the partial remainder exactly, instead of in carry-save "
                             "form like srt_core.vhd")
    args = parser.parse_args()

    removed = [table_index(*map(Fraction, r.split(":"))) for r in args.remove]
    table = build_table(removed, args.pla)

    if args.tikz:
        print_tikz(table)
        return

    carry_save = not args.exact

    if args.bounds:
        print_bounds(remainder_bounds(table, carry_save), per_column=True)
        return

    if args.n is not None:
        assert args.d is not None, "Both N and D must be given"
        assert 0 <= args.n < 2**32 and 0 <= args.d < 2**32, "Inputs must be 32-bit unsigned integers"
        show_division(args.n, args.d, table, args.trace, carry_save)
        return

    bad = check_table(table, carry_save)
    mode = "carry-save" if carry_save else "exact"
    print(f"Table check ({mode} partial remainder): {len(bad)} failing entries.")
    for idx in bad:
        n_lo, n_hi, d_lo, d_hi = cell_bounds(idx)
        print(f"  FAIL: entry {idx}: n in [{n_lo}, {n_hi}), d in [{d_lo}, {d_hi}), |q| = {table[idx]}")
    bounds = remainder_bounds(table, carry_save)
    print_bounds(bounds, per_column=False)

    errors = test(table, args.count, bad, carry_save=carry_save)

    for idx in bad:
        # An entry outside the range of the partial remainder is never used.
        # With carry-save, the entry is used for n up to one row above it.
        n_lo, n_hi, _, _ = cell_bounds(idx)
        if carry_save:
            n_hi += Fraction(1, 8)
        b = bounds[idx & 15]
        if b is not None and (n_hi <= b[0] or n_lo >= b[2]):
            print(f"Entry {idx}: Never used, since it is outside the range of the partial remainder.")
            continue
        if carry_save:
            print(f"Entry {idx}: Inside the range of the partial remainder, so it may be used.")
            continue
        found = find_input(idx, table)
        if found is None:
            print(f"Entry {idx}: No division found that uses it. It may be unreachable.")
        else:
            print(f"Entry {idx}: This division uses it:")
            show_division(*found, table, args.trace, carry_save)

    # Fail if any division in the test was wrong
    sys.exit(1 if errors else 0)


if __name__ == "__main__":
    main()
