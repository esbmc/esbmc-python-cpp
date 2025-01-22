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

    my_dict = {"a": 1, "b": 2, "c": 3}
    assert (my_dict["a"] == 1)
    del my_dict["b"]
    assert "b" not in my_dict

# Run the test
test_pop_from_dict()

print("Test passed!")


