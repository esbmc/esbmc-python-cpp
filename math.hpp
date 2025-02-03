#ifndef __MATH_HPP
#define __MATH_HPP

#include "builtin.hpp"

namespace shedskin {

void __init();

// Mathematical constants
const __ss_float M_PI = 3.14159265358979323846;
const __ss_float M_E = 2.71828182845904523536;

// Basic math functions
inline __ss_float fmod(__ss_float x, __ss_float y) {
    __ss_float quotient = (__ss_int)(x/y);
    return x - y * quotient;
}

inline __ss_float floor(__ss_float x) {
    __ss_int n = (__ss_int)x;
    return (x < 0 && x != n) ? n - 1 : n;
}

inline __ss_float ceil(__ss_float x) {
    __ss_int n = (__ss_int)x;
    return (x > 0 && x != n) ? n + 1 : n;
}

inline __ss_float pow(__ss_float x, __ss_float y) {
    if (y == 0) return 1;
    if (y == 1) return x;
    if (y == 2) return x * x;
    if (y == 3) return x * x * x;
    if (y == -1) return 1/x;
    
    __ss_bool negative = y < 0;
    y = negative ? -y : y;
    __ss_float result = 1;
    while (y >= 1) {
        result *= x;
        y -= 1;
    }
    if (y > 0) {
        result *= (1 + (x - 1) * y);
    }
    return negative ? 1/result : result;
}

// Power operations
inline __ss_float __power(__ss_int a, __ss_float b) { 
    return pow(a,b); 
}

inline __ss_float __power(__ss_float a, __ss_int b) { 
    if(b==2) return a*a;
    else if(b==3) return a*a*a;
    else return pow(a,b); 
}

template<class A> A __power(A a, A b);

template<> inline __ss_float __power(__ss_float a, __ss_float b) { 
    return pow(a,b); 
}

template<> inline __ss_int __power(__ss_int a, __ss_int b) {
    if(b < 0) return 0;
    switch(b) {
        case 0: return 1;
        case 1: return a;
        case 2: return a*a;
        case 3: return a*a*a;
        case 4: return a*a*a*a;
    }
    __ss_int res = 1;
    __ss_int tmp = a;
    while(b > 0) {
        if(b % 2) res *= tmp;
        tmp *= tmp;
        b /= 2;
    }
    return res;
}

// Division operations
inline __ss_float __divs(__ss_float a, __ss_float b) { 
    return a/b; 
}

inline __ss_int __divs(__ss_int a, __ss_int b) {
    if(a < 0 && b > 0) return (a - b + 1) / b;
    else if(b < 0 && a > 0) return (a - b - 1) / b;
    else return a / b;
}

// Float and modulo operations
inline __ss_float __mods(__ss_float a, __ss_float b) {
    __ss_float f = fmod(a, b);
    if((f < 0 && b > 0) || (f > 0 && b < 0)) 
        f += b;
    return f;
}

inline __ss_int __mods(__ss_int a, __ss_int b) {
    __ss_int m = a % b;
    if((m < 0 && b > 0) || (m > 0 && b < 0)) 
        m += b;
    return m;
}

inline __ss_float __mods(__ss_int a, __ss_float b) { 
    return __mods((__ss_float)a, b); 
}

inline __ss_float __mods(__ss_float a, __ss_int b) { 
    return __mods(a, (__ss_float)b); 
}

// Floor division
inline __ss_float __floordiv(__ss_float a, __ss_float b) { 
    return floor(a/b); 
}

inline __ss_int __floordiv(__ss_int a, __ss_int b) { 
    return (__ss_int)floor((__ss_float)a/b); 
}

inline __ss_float __floordiv(__ss_int a, __ss_float b) { 
    return floor((__ss_float)a/b); 
}

inline __ss_float __floordiv(__ss_float a, __ss_int b) { 
    return floor(a/(__ss_float)b); 
}

// Divmod operations
template<class A> 
tuple2<A,A>* divmod(A a, A b) {
    return new tuple2<A,A>(2, __floordiv(a,b), __mods(a,b));
}

inline tuple2<__ss_float,__ss_float>* divmod(__ss_float a, __ss_float b) {
    return new tuple2<__ss_float,__ss_float>(2, __floordiv(a,b), __mods(a,b));
}

inline tuple2<__ss_int,__ss_int>* divmod(__ss_int a, __ss_int b) {
    return new tuple2<__ss_int,__ss_int>(2, __floordiv(a,b), __mods(a,b));
}

// Float checks
inline __ss_bool __ss_is_integer(__ss_float d) {
    return __mbool(static_cast<__ss_int>(d) == d);
}

} // namespace shedskin

namespace __math__ = shedskin;

#endif