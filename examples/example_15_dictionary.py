
my_dict = {"a": 1, "b": 2, "c": True, "d": False,"e": "abc","f": "jwt"}
assert (my_dict["a"] == 1)
assert (my_dict["c"] == True)
assert (my_dict["f"] == "jwt")

del my_dict["b"]
assert "b" not in my_dict



