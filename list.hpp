#ifndef __LIST_HPP
#define __LIST_HPP

#include "builtin.hpp"

namespace shedskin {

template<class T> class list;
template<class T> class __iter;

// Forward declare the for_in_loop class outside the list class
template<class T>
struct __list_for_in_loop {
    __ss_int i;
    list<T>* l;
    __list_for_in_loop() : i(0), l(nullptr) {}
    __list_for_in_loop(list<T>* lst) : i(0), l(lst) {}
    bool __next__(T& ref) {
        if(!l || i >= l->__size) return false;
        ref = l->units[i++];
        return true;
    }
};

template<class T>
class list : public pyobj {
public:
    typedef T for_in_unit;
    typedef __list_for_in_loop<T> for_in_loop;

    T* units;
    __ss_int __size;

    list() {
        this->__class__ = cl_list;
        __size = 0;
        units = new T[1];
    }

    list(__ss_int size) {
        this->__class__ = cl_list;
        __size = size;
        units = new T[size];
    }

    list(__ss_int size, T t1) {
        this->__class__ = cl_list;
        __size = size;
        units = new T[size];
        if(size > 0) units[0] = t1;
    }

    list(__ss_int size, T t1, T t2) {
        this->__class__ = cl_list;
        __size = size;
        units = new T[size];
        if(size > 0) units[0] = t1;
        if(size > 1) units[1] = t2;
    }

    list(__ss_int size, T t1, T t2, T t3) {
        this->__class__ = cl_list;
        __size = size;
        units = new T[size];
        if(size > 0) units[0] = t1;
        if(size > 1) units[1] = t2;
        if(size > 2) units[2] = t3;
    }

    ~list() {
        delete[] units;
    }

    list(list<T>* p) {
        this->__class__ = cl_list;
        if(p) {
            __size = p->__size;
            units = new T[__size];
            for(__ss_int i = 0; i < __size; i++)
                units[i] = p->units[i];
        } else {
            __size = 0;
            units = new T[1];
        }
    }

    template<class U>
    list(U* iter) {
        this->__class__ = cl_list;
        __size = 0;
        units = new T[1];
        typename U::for_in_unit e;
        typename U::for_in_loop __3;
        __ss_int __2;
        U* __1;
        FOR_IN(e, iter, __2, 1, 2)
            append(e);
        END_FOR
    }

    void append(T x) {
        T* new_units = new T[__size + 1];
        for(__ss_int i = 0; i < __size; i++)
            new_units[i] = units[i];
        new_units[__size] = x;
        delete[] units;
        units = new_units;
        __size++;
    }

    __ss_int __len__() {
        return __size;
    }

    T __getitem__(__ss_int i) {
        if(i < 0) i += __size;
        return units[i];
    }

    void __setitem__(__ss_int i, T x) {
        if(i < 0) i += __size;
        units[i] = x;
    }

    T __getfast__(__ss_int i) {
        return units[i];
    }
};

extern class_* cl_list;

// Initialization function declaration
void __init();

} // namespace shedskin

#endif