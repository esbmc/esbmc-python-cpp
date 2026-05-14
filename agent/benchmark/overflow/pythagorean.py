"""Pythagorean theorem assertion (paper Fig. 5)."""
import esbmc

def main():
    x = esbmc.nondet_int()
    y = esbmc.nondet_int()
    z = esbmc.nondet_int()
    esbmc.__ESBMC_assume(0 < x < 16384)
    esbmc.__ESBMC_assume(0 < y < 16384)
    esbmc.__ESBMC_assume(0 < z < 16384)
    assert x * x + y * y != z * z, "Pythagorean triple found"

main()
