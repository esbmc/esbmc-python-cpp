import random

def __VERIFIER_nondet_int():
    """Simulates a non-deterministic integer value."""
    return random.randint(-100, 100)  # Adjust limits if necessary

def __VERIFIER_nondet_bool():
    """Simulates a non-deterministic Boolean value."""
    return bool(random.randint(0, 1))

# Main script
x: int = __VERIFIER_nondet_int()
y: int = x

if __VERIFIER_nondet_bool():
    x = x + 1
else:
    x = x + 2

assert(x != y)
