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
            return (x & 0x7fffffff) / (__ss_float)0x7fffffff;
        }
        
        __ss_int randrange(__ss_int stop) {
            return (__ss_int)(random() * stop);
        }
        
        __ss_int randrange(__ss_int start, __ss_int stop) {
            return start + (__ss_int)(random() * (stop - start));
        }
        
        __ss_int randrange(__ss_int start, __ss_int stop, __ss_int step) {
            __ss_int width = stop - start;
            return start + ((__ss_int)(random() * (width/step))) * step;
        }

        // Surcharge spéciale pour __ss_int qui retourne directement la valeur
        __ss_int choice(list<__ss_int>* lst) {
            if (!lst || lst->__len__() == 0) {
                throw ValueError(new str("Cannot choose from empty sequence"));
            }
            __ss_int index = (__ss_int)(random() * lst->__len__());
            return lst->__getitem__(index);
        }

        // Version template générique pour les autres types
        template<typename T>
        T* choice(list<T>* lst) {
            if (!lst || lst->__len__() == 0) {
                throw ValueError(new str("Cannot choose from empty sequence"));
            }
            __ss_int index = (__ss_int)(random() * lst->__len__());
            return new T(lst->__getitem__(index));
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

    int randint(int low, int high) {
        return nondet_int();
    }

    // Surcharge spéciale pour __ss_int
    __ss_int choice(list<__ss_int>* lst) {
        return _inst->choice(lst);
    }

    // Version template générique pour les autres types
    template<typename T>
    T* choice(list<T>* lst) {
        return _inst->choice(lst);
    }
}

#endif // __RANDOM_HPP