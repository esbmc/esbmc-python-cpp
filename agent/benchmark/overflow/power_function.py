"""Power function overflow (paper Table 2)."""
import esbmc

def main():
    base = esbmc.nondet_int()
    exp = esbmc.nondet_int()
    esbmc.__ESBMC_assume(2 <= base <= 100)
    esbmc.__ESBMC_assume(1 <= exp <= 20)
    result = 1
    i = 0
    while i < exp:
        result = result * base
        i = i + 1
    assert result > 0, "power overflow"

main()
