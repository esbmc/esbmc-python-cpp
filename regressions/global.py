import other

class MyClass:
  m_data: other.OtherClass

a = 1
d = 2
e = 1
z = blah()

def bar() -> None:
  f = e

def foo(e:MyClass) -> int:
  b = a
  assert b == 1
  bar()
  return d

obj = MyClass()
foo(obj)

