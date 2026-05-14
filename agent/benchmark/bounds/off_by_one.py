"""Off-by-one loop bounds violation (paper Table 2)."""
import esbmc

def main():
    data = [1, 2, 3, 4, 5]
    n = esbmc.nondet_int()
    esbmc.__ESBMC_assume(0 <= n <= 5)
    total = 0
    i = 0
    # Classic off-by-one: <= n with n possibly equal to length
    while i <= n:
        total = total + data[i]
        i = i + 1
    assert total >= 0

main()
