# example_7_comprehensions.py
def demonstrate_comprehensions():
    # List comprehension examples
    print("List Comprehensions:")

    # Basic even numbers
    even = [x for x in range(20) if x % 2 == 0]
    print("Even numbers:", even)

    # Squares of even numbers
    even_squares = [x**2 for x in range(10) if x % 2 == 0]
    print("Squares of even numbers:", even_squares)

    # Dictionary comprehension examples
    print("\nDictionary Comprehensions:")

    # Number to square mapping
    squares = {x: x**2 for x in range(5)}
    print("Number to square mapping:", squares)

    # Even number to square mapping
    even_squares_dict = {x: x**2 for x in range(10) if x % 2 == 0}
    print("Even number to square mapping:", even_squares_dict)

    # More complex example using strings
    words = ["hello", "world", "python", "comprehension"]
    word_lengths = {word: len(word) for word in words if len(word) > 5}
    print("Word length mapping (for words > 5 chars):", word_lengths)

if __name__ == "__main__":
    demonstrate_comprehensions()
