"""Safe bounded addition — should be VERIFIED."""
import esbmc

def main():
    a = esbmc.nondet_int()
    b = esbmc.nondet_int()
    esbmc.__ESBMC_assume(0 <= a <= 100)
    esbmc.__ESBMC_assume(0 <= b <= 100)
    s = a + b
    assert 0 <= s <= 200

main()
