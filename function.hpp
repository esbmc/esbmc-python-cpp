#ifndef __FUNCTION_HPP
#define __FUNCTION_HPP

#include "builtin.hpp"
#include "string.hpp"
#include "math.hpp"

using str;

typedef long long __ss_int;
typedef double __ss_float;
typedef bool __ss_bool;

class class_;

/* ---- Base Type Conversions ---- */

template<class T> inline __ss_int __int(T t) { 
    return t->__int__(); 
}
template<> inline __ss_int __int(__ss_int i) { 
    return i; 
}
template<> inline __ss_int __int(int i) { 
    return i; 
}
template<> inline __ss_int __int(__ss_bool b) { 
    return (__ss_int)b; 
}
template<> inline __ss_int __int(__ss_float d) { 
    return (__ss_int)d; 
}

template<class T> inline __ss_float __float(T t) { 
    return t->__float__(); 
}
template<> inline __ss_float __float(__ss_int p) { 
    return (__ss_float)p; 
}
template<> inline __ss_float __float(int p) { 
    return p; 
}
template<> inline __ss_float __float(__ss_bool b) { 
    return (__ss_float)b; 
}
template<> inline __ss_float __float(__ss_float d) { 
    return d; 
}

/* ---- String Conversion ---- */
template<class T> str *__str(T t) { 
    if (!t) return new str("None"); 
    return t->__str__(); 
}

/* ---- Length Operator ---- */
template<class T> inline __ss_int len(T x) { 
    return x->__len__(); 
}

/* ---- Basic Math ---- */
template<class T> inline T __abs(T t) { 
    return t->__abs__(); 
}
template<> inline __ss_int __abs(__ss_int a) { 
    return a<0?-a:a; 
}
template<> inline int __abs(int a) { 
    return a<0?-a:a; 
}
template<> inline __ss_float __abs(__ss_float a) { 
    return a<0?-a:a; 
}

/* ---- Basic Math Operations ---- */
template<class T> inline bool operator<(const T a, const T b) { 
    return a.__lt__(b); 
}
template<class T> inline bool operator>(const T a, const T b) { 
    return b.__lt__(a); 
}

/* ---- Min/Max ---- */
template<class T> inline T ___min(T a, T b) { 
    return (a < b) ? a : b; 
}
template<class T> inline T ___max(T a, T b) { 
    return (a > b) ? a : b; 
}

/* ---- Type Checking ---- */
template<class T> class_ *__type(T t) { 
    return t->__class__; 
}

template<class T> inline bool isinstance(T obj, class_ *cls) {
    return obj->__class__ == cls;
}

#endif /* __FUNCTION_HPP */