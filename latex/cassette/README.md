# cassette
Cassette Tape Counter and Playing Time (September 2026).

How does the counter reading on a cassette deck relate to the elapsed playing
time? The tape moves at a constant speed, but the radius of the tape on each
reel changes, so the reels turn at varying speeds.

The document `cassette.tex` derives a physical model in which the time is a
quadratic function of the counter reading, $t = aN + bN^2$. It then shows how to
fit this model to measurements:

* Least squares fitting and the uncertainty in the fitted coefficients.
* Recovering the physical parameters (hub radius, tape thickness and tape
  speed). The fit only gives two numbers, so one of the three must be known
  in advance.
* Sources of error, and how to design the experiment.
