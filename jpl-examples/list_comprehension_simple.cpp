#include "builtin.hpp"
#include "random.hpp"
#include "math.hpp"
#include "time.hpp"
#include "esbmc.hpp"
#include "list_comprehension_simple.hpp"

namespace __list_comprehension_simple__ {

str *const_0, *const_1, *const_2, *const_3;

using __esbmc__::Thread;
using __esbmc__::Topic;

str *__name__;
__ss_int counter;


static inline list<Action *> *list_comp_0(lambda0 condition, list<Action *> *actions);
static inline __ss_bool __lambda0__(Action *a);

static inline list<Action *> *list_comp_0(lambda0 condition, list<Action *> *actions) {
    Action *action;
    list<Action *> *__16;
    __iter<Action *> *__17;
    __ss_int __18;
    list<Action *>::for_in_loop __19;

    list<Action *> *__ss_result = new list<Action *>();

    FOR_IN(action,actions,16,18,19)
        if (condition(action)) {
            __ss_result->append(action);
        }
    END_FOR

    return __ss_result;
}

static inline __ss_bool __lambda0__(Action *a) {
    return a->pre();
}

list<Action *> *list_comp(list<Action *> *actions, lambda0 condition) {
    return list_comp_0(condition, actions);
}

/**
class Action
*/

class_ *cl_Action;

/**
class Down
*/

class_ *cl_Down;

__ss_bool Down::pre() {
    return ___bool((__list_comprehension_simple__::counter>__ss_int(0)));
}

void *Down::act() {
    __ESBMC_assume(counter > 0);
    counter = (__list_comprehension_simple__::counter-__ss_int(1));
    ASSERT(___bool((__list_comprehension_simple__::counter>=__ss_int(0))), 0);
    print(__add_strs(2, __str(const_0), __str(__list_comprehension_simple__::counter)));
    return NULL;
}

/**
class Up
*/

class_ *cl_Up;

__ss_bool Up::pre() {
    return ___bool((__list_comprehension_simple__::counter<__ss_int(1)));
}

void *Up::act() {
    __ESBMC_assume(counter < 1);
    counter = (__list_comprehension_simple__::counter+__ss_int(1));
    ASSERT(___bool((__list_comprehension_simple__::counter<=__ss_int(1))), 0);
    print(__add_strs(2, __str(const_1), __str(__list_comprehension_simple__::counter)));
    return NULL;
}

void *__ss_main() {
    list<Action *> *actions, *enabled_actions;
    __ss_int action_nr, length;
    Action *action;

    actions = (new list<Action *>(2,((Action *)((new Down()))),((Action *)((new Up())))));

    while (True) {
        enabled_actions = list_comp(actions, __lambda0__);
        if (___bool(enabled_actions)) {
            length = len(enabled_actions);
            action_nr = __random__::randint(__ss_int(0), (length-__ss_int(1)));
            print(__add_strs(4, __str(const_2), __str(length), __str(const_3), __str(action_nr)));
            action = enabled_actions->__getfast__(action_nr);
            action->act();
        }
    }
    return NULL;
}

void __init() {
    const_0 = new str("counting down: ");
    const_1 = new str("counting up: ");
    const_2 = new str("length=");
    const_3 = new str(" action=");

    __name__ = new str("__main__");

    cl_Action = new class_("Action");
    cl_Down = new class_("Down");
    cl_Up = new class_("Up");
    counter = __ss_int(1);
    __ss_main();
}

} // module namespace

int main(int, char **) {
    __shedskin__::__init();
    __math__::__init();
    __time__::__init();
    __random__::__init();
    __esbmc__::__init();
    __shedskin__::__start(__list_comprehension_simple__::__init);
}
