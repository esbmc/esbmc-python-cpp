"""Factorial overflow (paper Table 2)."""
import esbmc

def main():
    n = esbmc.nondet_int()
    esbmc.__ESBMC_assume(0 < n < 20)
    result = 1
    i = 1
    while i <= n:
        result = result * i
        i = i + 1
    assert result > 0, "factorial overflow"

main()
