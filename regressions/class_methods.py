class MyClass:
    @staticmethod
    def my_method() -> int:
        return 1

# Appel explicite de la méthode
result = MyClass.my_method()
assert result == 1