"""Safe array indexing — should be VERIFIED."""
import esbmc

def main():
    arr = [10, 20, 30, 40, 50]
    idx = esbmc.nondet_int()
    esbmc.__ESBMC_assume(0 <= idx < 5)
    value = arr[idx]
    assert 10 <= value <= 50

main()
