def f(x: str) -> str:
    return x
assert f("abc") == "abc"
assert f("abcd") != "abc"
