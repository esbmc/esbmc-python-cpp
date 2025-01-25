"""il n'est pas possible d'utiliser directement x.bit_length() avec Shedskin, car Shedskin ne prend pas en charge cette méthode spécifique de Python"""
def bit_length(x: int) -> int:
    """Returns the number of bits required to represent x in binary."""
    if x == 0:
        return 0
    length = 0
    while x > 0:
        length += 1
        x >>= 1
    return length

x = int(16)
assert x.bit_length() == 4 # Expected bit length for integer 16 should be 5
