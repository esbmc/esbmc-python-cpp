# example_12_string.py
class ExampleClass:
    def __init__(self, name: str) -> None:
        self.name = name

    def __str__(self) -> str:
        # ESBMC requires explicit string conversion of all parts
        name_str: str = self.name  # No need for str() since name is already str
        return "ExampleClass(name=" + name_str + ")"

def demonstrate_string_functions() -> None:
    # Basic string conversion
    obj = ExampleClass("test")
    # ESBMC requires explicit string conversion
    obj_str: str = obj.__str__()  # Use direct method call instead of str()
    assert obj_str == "ExampleClass(name=test)"

if __name__ == "__main__":
    def main() -> None:
        demonstrate_string_functions()
    main()
