a = 1
b = 2

# Equality
assert (a == b) == False, "Equality check failed"
assert (a == 1) == True, "Equality check for 'a' failed"

# Inequality
assert (a != b) == True, "Inequality check failed"
assert (a != 1) == False, "Inequality check for 'a' failed"

# Greater than
assert (b > a) == True, "Greater than check failed"
assert (a > b) == False, "Greater than check for 'a' failed"

# Less than
assert (a < b) == True, "Less than check failed"
assert (b < a) == False, "Less than check for 'b' failed"

# Greater than or equal to
assert (b >= a) == True, "Greater than or equal check failed"
assert (a >= b) == False, "Greater than or equal check for 'a' failed"

# Less than or equal to
assert (a <= b) == True, "Less than or equal check failed"
assert (b <= a) == False, "Less than or equal check for 'b' failed"
