"""Dynamic index bounds violation (paper Table 2)."""
import esbmc

def main():
    arr = [10, 20, 30, 40, 50]
    idx = esbmc.nondet_int()
    esbmc.__ESBMC_assume(0 <= idx <= 5)  # 5 is out of bounds for a 5-element list
    value = arr[idx]
    assert value >= 10

main()
