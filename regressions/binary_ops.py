result_add = 1 + 0  
result_sub = 1 - 0
result_mul = 1 * 0
result_div = 1   
result_idiv = -3  
assert(result_idiv == -3)
result_idiv = 2   
assert(result_idiv == 2)
result_mod = 0
result_out = 1 | 1
result_in = 1 & 0
result_x = 3 ^ 1
result_left = 2 << 1
result_right = 2 >> 1

def add_nums(x:int, y:int) -> int:
    z = x + y
    return z

assert add_nums(1,2) == 3