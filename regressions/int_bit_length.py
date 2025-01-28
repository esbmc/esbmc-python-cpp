"""it is not possible to use a.bit_length() directly with Shedskin, as Shedskin does not support this Python-specific method"""

def bit_length(x: int) -> int:
    """Returns the number of bits required to represent x in binary."""
    if x == 0:
        return 0
    length = 0
    while x > 0:
        length += 1
        x >>= 1
    return length

# Replace calls to int.bit_length() with bit_length()
a = 0
assert bit_length(a) == 0

b = 16
assert bit_length(b) == 5

c = 255
assert bit_length(c) == 8

d = 5
assert bit_length(d - 1) == 3

def foo(x: int) -> int:
    return bit_length(x - 1)

e = 5
f = bit_length(e)
assert f == 3

g = bit_length(e) - 1
assert g == 2

def foo2(x: int) -> None:
    y = bit_length(x)