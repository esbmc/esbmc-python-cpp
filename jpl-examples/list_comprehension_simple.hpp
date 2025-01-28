#ifndef __LIST_COMPREHENSION_SIMPLE_HPP
#define __LIST_COMPREHENSION_SIMPLE_HPP

using namespace __shedskin__;
namespace __list_comprehension_simple__ {

extern str *const_0, *const_1, *const_2, *const_3;

class Action;
class Down;
class Up;

typedef __ss_bool (*lambda0)(Action *);

extern str *__name__;
extern __ss_int counter;


extern class_ *cl_Action;
class Action : public pyobj {
public:

    Action() { this->__class__ = cl_Action; }
    virtual __ss_bool  pre() { return False; };
    virtual void *act() { return 0; };
};

extern class_ *cl_Down;
class Down : public Action {
public:

    Down() { this->__class__ = cl_Down; }
    __ss_bool pre();
    void *act();
};

extern class_ *cl_Up;
class Up : public Action {
public:

    Up() { this->__class__ = cl_Up; }
    __ss_bool pre();
    void *act();
};

list<Action *> *list_comp(list<Action *> *actions, lambda0 condition);
void *__ss_main();

} // module namespace
#endif
