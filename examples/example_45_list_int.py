#!/usr/bin/env python3
from typing import List

def sum_while(n: List[int]) -> int:
    l = len(n)
    i = 0
    s = 0
    while i < l:
        s += n[i]
        i += 1
    return s

assert sum_while([1, 2, 3, 4]) == 11
