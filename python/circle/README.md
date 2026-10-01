# circle
How do you generate a circle using only addition and subtraction?

Starting at $(R, 0)$, the script `circle.py` repeatedly applies the update

$$x \leftarrow x - a y, \qquad y \leftarrow y + a x$$

with a small step $a$. The points lie exactly on an ellipse tilted 45 degrees,
and the period is $T = 2\pi/v$, where $a = 2\sin(v/2)$.

When $x$ and $y$ are integers and the products are truncated, the period gets
longer. The script measures this and finds that the period is approximately

$$T \approx \frac{2\pi + 4/(Ra)}{a}.$$

The full derivation is in the comments at the top of the script.
`circle.xlsx` contains plots of the results.
