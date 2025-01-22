# example_6_lists.py
from typing import List

class Task:
    def __init__(self, name: str, priority: int = 0):
        self.name = name
        self.priority = priority

    def __str__(self):
        return f"Task({self.name}, priority={self.priority})"

def demonstrate_lists():
    # Create list of tasks
    tasks: List[Task] = []

    # Add some tasks
    tasks.append(Task("First Task", 1))
    tasks.append(Task("Second Task", 2))
    tasks.append(Task("Priority Task", 3))

    # Demonstrate list operations
    print("All tasks:")
    for task in tasks:
        print(task)

    # Demonstrate indexing
    print("\nFirst task:", tasks[0])

    # Demonstrate sorting with custom key
    sorted_tasks = sorted(tasks, key=lambda x: x.priority, reverse=True)
    print("\nSorted by priority (descending):")
    for task in sorted_tasks:
        print(task)

    # Demonstrate removal
    removed_task = tasks.pop(1)
    print(f"\nRemoved task: {removed_task}")
    print("Remaining tasks:")
    for task in tasks:
        print(task)

if __name__ == "__main__":
    demonstrate_lists()
