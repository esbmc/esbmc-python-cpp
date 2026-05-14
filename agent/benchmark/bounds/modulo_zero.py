"""Modulo by zero (paper Table 2)."""
import esbmc

def main():
    a = esbmc.nondet_int()
    b = esbmc.nondet_int()
    esbmc.__ESBMC_assume(1 <= a <= 1000)
    esbmc.__ESBMC_assume(0 <= b <= 10)
    result = a % b
    assert result >= 0

main()
