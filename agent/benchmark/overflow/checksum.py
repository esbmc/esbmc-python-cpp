"""Checksum overflow (paper Table 2)."""
import esbmc

def main():
    a = esbmc.nondet_int()
    b = esbmc.nondet_int()
    c = esbmc.nondet_int()
    esbmc.__ESBMC_assume(a > 0 and b > 0 and c > 0)
    esbmc.__ESBMC_assume(a < 2**30 and b < 2**30 and c < 2**30)
    checksum = a + b + c
    assert checksum >= a, "checksum overflow"

main()
