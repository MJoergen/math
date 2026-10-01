# euler
Project Euler, problem 318 (December 2023).

The even powers of $\sqrt 2 + \sqrt 3$ have more and more nines at the start
of their fractional part. The problem asks how many nines there are for
numbers of the form $\sqrt p + \sqrt q$.

The document `euler.tex` writes $(\sqrt p + \sqrt q)^{2n}$ as an integer minus
$(\sqrt q - \sqrt p)^{2n}$. This gives a closed-form expression for the
number of nines in terms of $\log_{10}(\sqrt q - \sqrt p)$.
