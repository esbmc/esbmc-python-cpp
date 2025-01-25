def nondet_int():
    """Simulates a non-deterministic integer value."""
    return 42  # Example: Replace with a real value.

def nondet_bool():
    """Simulates a non-deterministic Boolean value."""
    return True  # Example: Replace with real logic.

x: int = nondet_int()
y: int = x

if (nondet_bool()):
    x = x + 1
else:
    x = x + 2

# Reformulate the assertion
assert (x != y and x == y + 1 )
