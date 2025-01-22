import random
from esbmc import *

def list_comp(actions, condition):
    return [action for action in actions if condition(action)]

class Action:
    def pre(self) -> bool:
        pass
    def act(self):
        pass
counter: int = 5
class Down(Action):
    def pre(self) -> bool:
        return counter > 0
    def act(self):
        global counter
        counter -= 1
        print(f'counting down: {counter}')
class Up(Action):
    def pre(self) -> bool:
        return counter < 10
    def act(self):
        global counter
        counter += 1
        print(f'counting up: {counter}')
def main():
    actions = [Down(), Up()]
    while True:
        enabled_actions = list_comp(actions, lambda a: a.pre())
        assert False
        if enabled_actions:
            length = len(enabled_actions)
            action_nr = random.randint(0, length-1)
            print(f'length={length} action={action_nr}')
            action = enabled_actions[action_nr]
            action.act()
            time.sleep(0.5)
            
if __name__ == "__main__":
    main()
