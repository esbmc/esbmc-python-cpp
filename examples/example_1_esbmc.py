# example_1_esbmc.py
from esbmc import nondet_int, __ESBMC_assume
import random

def basic_esbmc_example():
    n: int = nondet_int()
    assert(n > 0)
    # Add an assert here to force ESBMC to check the value
    # Add a final assert to make the contradiction explicit
    return n

def random_example():
    n: int = random.randrange(1, 6)
    return n

if __name__ == "__main__":
    print("ESBMC example result:", basic_esbmc_example())
    print("Random example result:", random_example())
