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
            __ss_int x = nondet_int();  // Changed to use nondet_int directly
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

    // Function to generate a random integer between low and high (inclusive)
    int randint(int low, int high) {
        return nondet_int();
    }
}

#endif // __RANDOM_HPP
