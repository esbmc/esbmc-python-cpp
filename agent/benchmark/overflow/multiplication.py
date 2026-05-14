"""Multiplication overflow (paper Table 2)."""
import esbmc

def main():
    a = esbmc.nondet_int()
    b = esbmc.nondet_int()
    esbmc.__ESBMC_assume(0 < a < 2**20)
    esbmc.__ESBMC_assume(0 < b < 2**20)
    product = a * b
    assert product >= a, "multiplication overflow"

main()
