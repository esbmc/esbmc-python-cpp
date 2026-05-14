"""Average with zero items — division by zero (paper Table 2)."""
import esbmc

def main():
    n = esbmc.nondet_int()
    esbmc.__ESBMC_assume(0 <= n <= 10)
    total = 0
    i = 0
    while i < n:
        total = total + i
        i = i + 1
    # When n == 0 the program divides by zero.
    average = total // n
    assert average >= 0

main()
