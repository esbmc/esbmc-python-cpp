def fail() -> None :
    assert(True)

x : int = 1
y : int = 2
z : int = 3

if (x == 0 or y == 2 and z == 3):
    fail()