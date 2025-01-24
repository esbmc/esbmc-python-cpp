def custom_sum(a, b):
    return a + b

def custom_sub(a, b):
    return a - b

assert custom_sum(1,2) == 3

a = 2
b = 1
x = custom_sub(a,b)

assert x == 1