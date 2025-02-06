#ifndef __RANDOM_HPP
#define __RANDOM_HPP

#include "builtin.hpp"
#include "math.hpp"

namespace __random__ {
    using namespace __shedskin__;
    using __math__::ValueError;

    extern str* __name__;

    class Random {
    public:
        Random() {}
        
        virtual __ss_float random() {
            __ss_int x = nondet_int();
            if (x < 0) x = -x;
            return (x % 0x7fffffff) / (__ss_float)0x7fffffff;
        }
        
        __ss_int randrange(__ss_int stop) {
            if (stop <= 0) {
                throw ValueError(new str("Stop argument must be positive"));
            }
            __ss_int x = nondet_int();
            return x % stop;
        }
        
        __ss_int randrange(__ss_int start, __ss_int stop) {
            if (stop <= start) {
                throw ValueError(new str("Stop argument must be greater than start"));
            }
            __ss_int width = stop - start;
            __ss_int x = nondet_int();
            if (x < 0) x = -x;
            return start + (x % width);
        }
        
        __ss_int randrange(__ss_int start, __ss_int stop, __ss_int step) {
            if (step == 0) {
                throw ValueError(new str("Step argument cannot be zero"));
            }
            __ss_int width = stop - start;
            if (width <= 0) {
                throw ValueError(new str("Invalid range"));
            }
            __ss_int n = width / step;
            if (n <= 0) {
                throw ValueError(new str("Empty range for given step"));
            }
            __ss_int x = nondet_int();
            if (x < 0) x = -x;
            return start + (x % n) * step;
        }

        __ss_int randint(__ss_int low, __ss_int high) {
            if (high < low) {
                throw ValueError(new str("High value must be greater than or equal to low value"));
            }
            __ss_int x = nondet_int();
            if (x < low) x = low;
            if (x > high) x = high;
            return x;
        }

        // Special case for __ss_int list
        __ss_int choice(list<__ss_int>* lst) {
            if (!lst || lst->__len__() == 0) {
                throw ValueError(new str("Cannot choose from empty sequence"));
            }
            __ss_int len = lst->__len__();
            __ss_int x = nondet_int();
            if (x < 0) x = -x;
            return lst->__getitem__(x % len);
        }

        // Generic version for other types
        template<class T>
        T* choice(list<T>* lst) {
            if (!lst || lst->__len__() == 0) {
                throw ValueError(new str("Cannot choose from empty sequence"));
            }
            __ss_int len = lst->__len__();
            __ss_int x = nondet_int();
            if (x < 0) x = -x;
            return new T(lst->__getitem__(x % len));
        }
    };

    extern Random* _inst;

    // Function declarations
    __ss_int nondet_int();
    void __init();
    
    __ss_int randrange(__ss_int stop) { 
        return _inst->randrange(stop); 
    }

    __ss_int randrange(__ss_int start, __ss_int stop) { 
        return _inst->randrange(start, stop); 
    }

    __ss_int randrange(__ss_int start, __ss_int stop, __ss_int step) { 
        return _inst->randrange(start, stop, step); 
    }

    __ss_int randint(__ss_int low, __ss_int high) {
        return _inst->randint(low, high);
    }

    // Special case for __ss_int list
    __ss_int choice(list<__ss_int>* lst) {
        return _inst->choice(lst);
    }

    // Generic version for other types
    template<class T>
    T* choice(list<T>* lst) {
        return _inst->choice(lst);
    }
}

#endif // __RANDOM_HPP