import esbmc
import random

def integer_squareroot(n):
    if n <= 0:
        return 0
    x = n
    y = (x + 1) // 2
    while y < x:
        x = y
        y = (x + n // x) // 2
    return x

n = esbmc.nondet_uint()
# This also triggers the bug and is good for testing
x = integer_squareroot(n)
# x = integer_squareroot(n)

assert x >= 0

# r = random.randint(0, 100)
# print(r)
# assert 0<=r<=100