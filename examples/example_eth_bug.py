import esbmc

def integer_squareroot(n: uint64) -> uint64:
    x = n
    y = (x + 1) // 2
    while y < x:
        x = y
        y = (x + n // x) // 2
    return x

n = esbmc.nondet_uint64()
# This also triggers the bug and is good for testing
# x = integer_squareroot(2**64-1)
x = integer_squareroot(n)

assert x >= 0
