# card_distrib
Counts the possible distributions of the four suits in a 13-card bridge hand,
such as 4-3-3-3 or 5-4-3-1.

* `brute_force.py`: Lists every ordered distribution, i.e. all
  $\binom{16}{3} = 560$ of them. Pipe the output through
  `sort -n -r | uniq -c` to count how often each pattern occurs.
* `card_distrib.py`: Lists the 39 distinct patterns. For each one it prints
  the number of suit permutations and the number of ways to assign the cards.
  It also prints the probability, assuming each card's suit is independently
  and uniformly random (i.e. divided by $4^{13}$).
* `partition.py`: Computes the partition numbers $p(n,k)$ recursively and
  checks them against closed-form formulas for $k = 2, 3, 4$. The number of
  patterns is $p(17,4) = 39$.
* `card_distrib.ods`: A spreadsheet with the results.
