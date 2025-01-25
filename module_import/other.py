def OtherFunction() -> int:
    return 1

class OtherClass:
    def foo(self, cls) -> int:
        return 3
    
def sum_values(a: int, b: int) -> int:
    return a + b

def sub_values(a: int, b: int) -> int:
    return a - b

def bit_length_b(x: int) -> int:
    """Returns the number of bits required to represent x in binary."""
    if x == 0:
        return 0
    length = 0
    while x > 0:
        length += 1
        x >>= 1
    return length