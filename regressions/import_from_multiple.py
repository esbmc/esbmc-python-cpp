def custom_sum(a, b):
    return a + b

class OtherClass:
    def foo(self):
        return 3

obj = OtherClass()

assert obj.foo() == 3
assert custom_sum(1,2) == 3