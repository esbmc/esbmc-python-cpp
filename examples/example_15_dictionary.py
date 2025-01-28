def test_pop_from_dict():
    # Create a dictionary
    

    # Pop a key-value pair from the dictionary
    # value = my_dict.pop("b", -1)
    # del my_dict["b"]
    # Assert the value is as expected
    # assert value == 2, "The popped value should be 2"
    # print(my_dict)
    # Assert the key is no longer in the dictionary
    # assert "b" not in my_dict, "The key 'b' should no longer be in the dictionary"

    my_dict = {"a": 1, "b": 2, "c": 3, "d": 4,"e": 5, "f": 6, "j": 7, "h": 8, "z": 9, "y": 10, "x": 11, "w": 12, "v": 13, "u": 14, "t": 15, "s": 16, "r": 17, "q": 18, "p": 19, "o": 20, "n": 21, "m": 22, "l": 23, "k": 24}
    assert (my_dict["a"] == 1)
    assert (my_dict["b"] == 2)
    assert (my_dict["c"] == 3)
    del my_dict["b"]
    assert "b" not in my_dict

# Run the test
test_pop_from_dict()

print("Test passed!")


