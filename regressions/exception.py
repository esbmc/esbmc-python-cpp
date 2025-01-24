class NegativeValueError(Exception):
    pass
def foo(value:int) -> int:
    if value < 0:
        raise NegativeValueError("Negative value!")

    return value * 2


result = 1

try:
  result = foo(-1)
except NegativeValueError as e:
  print(e)

assert result == 1
