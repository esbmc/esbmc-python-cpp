from typing import Optional

class List:
    def __init__(self, head: int, tail: Optional["List"]):
        self.head = head
        self.tail = tail

l1 = List(1, None)
l2 = List(2,l1)
