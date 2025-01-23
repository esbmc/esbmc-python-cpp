class MyClass:
   # Class attribute
   class_attr = 1

   def __init__(self, value):
       # Instance attribute
       self.data = value
       # Instance storage for class_attr override
       self._class_attr = None

   def get_attr(self):
       if hasattr(self, '_class_attr'):
           return self._class_attr
       return MyClass.class_attr

   def set_attr(self, value):
       self._class_attr = value

assert MyClass.class_attr == 1

obj1 = MyClass(10) 
obj1.set_attr(2)
assert obj1.get_attr() == 2
assert MyClass.class_attr == 1

obj2 = MyClass(15)
assert obj2.get_attr() == 1

MyClass.class_attr = 3
assert MyClass.class_attr == 3
assert obj1.get_attr() == 2
assert obj2.get_attr() == 3