"""Circle circumference overflow (paper Table 2)."""
import esbmc

def main():
    r = esbmc.nondet_int()
    esbmc.__ESBMC_assume(0 < r < 1_000_000_000)
    # 2 * 3 * r — overflows for r near INT32_MAX/6
    circumference = 6 * r
    assert circumference > 0, "circumference overflow"

main()
