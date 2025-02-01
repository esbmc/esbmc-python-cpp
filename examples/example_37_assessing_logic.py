a = True
b = False

# AND operation
assert (a and b) == False, "AND operation failed"

# OR operation
assert (a or b) == True, "OR operation failed"

# NOT operation
assert (not a) == False, "NOT operation on 'a' failed"
assert (not b) == True, "NOT operation on 'b' failed"

# XOR operation (exclusive OR)
assert (a ^ b) == True, "XOR operation failed"
assert (a ^ a) == False, "XOR operation with same values failed"
