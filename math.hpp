#ifndef __MATH_HPP
#define __MATH_HPP

#include "builtin.hpp"
#include <cmath>
#include <float.h>

#ifdef isfinite
#undef isfinite
#endif

#ifdef isinf
#undef isinf
#endif

#ifdef isnan
#undef isnan
#endif

namespace __math__ {
    using namespace __shedskin__;

    extern str* __name__;

    const __ss_float pi = 3.14159265358979323846;
    const __ss_float e = 2.71828182845904523536;

    class ValueError {
    public:
        str* message;
        ValueError(str* msg) : message(msg) {}
    };

    // Custom implementation without std::isfinite
    inline __ss_bool isfinite(__ss_float x) {
        return x == x && x != INFINITY && x != -INFINITY;
    }

    inline __ss_bool isnan(__ss_float x) {
        return x != x;
    }

    inline __ss_bool isinf(__ss_float x) {
        return x == INFINITY || x == -INFINITY;
    }

    void __init() {
        __name__ = new str("math");
    }
}

#endif // __MATH_HPP
