import random
from esbmc import *

def list_comp(actions, condition):
    return [action for action in actions if condition(action)]

class Action:
    def pre(self) -> bool:
        pass
    def act(self):
        pass



class Down(Action):
    def pre(self) -> bool:
        return counter > 0
    def act(self):
        global counter
        counter -= 1
        assert counter >= 0
        print(f'counting down: {counter}')

        
class Up(Action):
    def pre(self) -> bool:
        return counter <= 10
    def act(self):
        global counter
        counter += 1
        assert counter <= 10
        print(f'counting up: {counter}')


class Check(Action):
    def pre(self) -> bool:
        return True
    def act(self):
        print(f'Checking counter: {counter}')
        assert 0 <= counter <= 10
                
        
def main():
    actions = [Down(), Up(), Check()]
    while True:
        enabled_actions = list_comp(actions, lambda a: a.pre())
        if enabled_actions:
            length = len(enabled_actions)
            action_nr = random.randint(0, length-1)
            print(f'length={length} action={action_nr}')
            action = enabled_actions[action_nr]
            action.act()

counter: int = 5
            
if __name__ == "__main__":
    main()
