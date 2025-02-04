/* Copyright 2005-2024 Mark Dufour and contributors; License Expat (See LICENSE) */

#ifndef SS_BUILTIN_HPP
#define SS_BUILTIN_HPP

// Core C includes first
#include <stdlib.h>
#include <stddef.h>
#include <stdint.h>
#include <string.h>
#include <math.h>
#include <ctype.h>
#include <limits.h>

// Global operator new/delete
void* operator new(size_t size) {
    void* p = malloc(size);
    if (!p) throw "bad_alloc";
    return p;
}

void* operator new[](size_t size) {
    void* p = malloc(size);
    if (!p) throw "bad_alloc";
    return p;
}

void operator delete(void* ptr) noexcept { free(ptr); }
void operator delete[](void* ptr) noexcept { free(ptr); }

void* operator new(size_t, void* ptr) noexcept { return ptr; }
void* operator new[](size_t, void* ptr) noexcept { return ptr; }

// Import C functions into global namespace
using ::size_t;
using ::ptrdiff_t;
using ::malloc;
using ::free;
using ::strtol;
using ::strtoul;
using ::strtoll;
using ::strtoull;
using ::strtof;
using ::strtod;
using ::strtold;

// Type traits and utilities in isolated namespace
namespace shedskin_rt {
    // Type info base class with defaults
    template<typename T> 
    struct __type_info {
        typedef T type;
        static const bool is_specialized = false;
        static const bool is_signed = false;
        static const bool is_integer = false;
        static const int digits = 0;
        static const int digits10 = 0;
        static const int max_digits10 = 0;
    };

    // Specialization for int
    template<>
    struct __type_info<int> {
        typedef int type;
        static const bool is_specialized = true;
        static const bool is_signed = true;
        static const bool is_integer = true;
        static const int digits = sizeof(int) * CHAR_BIT - 1;
        static const int digits10 = digits * 301/1000;
        static const int max_digits10 = digits10;
    };
}

// Forward declare specific versions of std namespace to prevent conflicts
namespace std {
    template<typename T> class numeric_limits;
}

namespace std1 {
    namespace std {
        template<typename T> class numeric_limits;
    }
}

// Define required std namespace contents
namespace std {
    using ::size_t;
    using ::ptrdiff_t;

    template<typename T>
    class numeric_limits : public shedskin_rt::__type_info<T> {};
}

// Define required std1::std namespace contents
namespace std1 {
    namespace std {
        using ::size_t;
        using ::ptrdiff_t;
        
        template<typename T>  
        class numeric_limits : public shedskin_rt::__type_info<T> {};
    }

    // Forward declare ESBMC headers last
    #include "definitions.h"
    #include "vector"
    #include "deque"
    #include "list"
    #include "map"
    #include "set"
    #include "string"
    #include "sstream"
    #include "iostream"
}

#ifdef __SS_BIND
#include <Python.h>
#endif

#ifdef WIN32
#define GC_NO_INLINE_STD_NEW
#endif

#ifdef SHEDSKIN
#include <gc/gc_allocator.h>
#include <gc/gc_cpp.h>
#endif

namespace __shedskin__ {
    /* integer type */
    #if defined(__SS_INT32)
        typedef int32_t __ss_int;
    #elif defined(__SS_INT64)
        typedef int64_t __ss_int;
        #define __SS_LONG
    #elif defined(__SS_INT128)
        typedef __int128 __ss_int;
        #define __SS_LONG
    #else
        typedef int __ss_int;
    #endif

    /* float type */
    #if defined(__SS_FLOAT32)
        typedef float __ss_float;
    #else
        typedef double __ss_float;
    #endif

    /* STL types with gc_allocator */
    #define __GC_VECTOR(T) std1::vector< T, gc_allocator< T > >
    #define __GC_DEQUE(T) std1::deque< T, gc_allocator< T > >
    #define __GC_STRING std1::basic_string<char,std1::char_traits<char>,gc_allocator<char> >


#endif
/* Root object class */
class pyobj : public gc {
public:
    class_ *__class__;
    virtual str *__repr__();
    virtual str *__str__();
    virtual long __hash__();
    virtual __ss_int __cmp__(pyobj *p);
    virtual __ss_bool __eq__(pyobj *p);
    virtual __ss_bool __ne__(pyobj *p);
    virtual __ss_bool __gt__(pyobj *p);
    virtual __ss_bool __lt__(pyobj *p);
    virtual __ss_bool __ge__(pyobj *p);
    virtual __ss_bool __le__(pyobj *p);
    virtual pyobj *__copy__();
    virtual pyobj *__deepcopy__(dict<void *, pyobj *> *);
    virtual __ss_int __len__();
    virtual __ss_int __int__();
    virtual __ss_bool __nonzero__();
    virtual __ss_int __index__();

    static const bool is_pyseq = false;
};
/* abstract iterable class */
template <class T> class pyiter : public pyobj {
public:
    virtual __iter<T> *__iter__() = 0;
    virtual __ss_bool __contains__(T t);

    typedef T for_in_unit;
    typedef __iter<T> * for_in_loop;

    inline __iter<T> *for_in_init();
    inline bool for_in_has_next(__iter<T> *iter);
    inline T for_in_next(__iter<T> *iter);
};

/* abstract sequence class */
template <class T> class pyseq : public pyiter<T> {
public:
    virtual __ss_int __len__() = 0;
    virtual T __getitem__(__ss_int i) = 0;
    virtual __ss_int __cmp__(pyobj *p);
    virtual __iter<T> *__iter__();

    typedef T for_in_unit;
    typedef size_t for_in_loop;

    inline size_t for_in_init();
    inline bool for_in_has_next(size_t i);
    inline T for_in_next(size_t &i);

    static const bool is_pyseq = true;
};

/* iterator class */
template<class T> class __iter : public pyiter<T> {
public:
    T __result;
    bool __stop_iteration;

    __iter<T> *__iter__();
    virtual T __next__();
    virtual T __get_next();
    str *__repr__();
};

/* sequence iterator */
template <class T> class __seqiter : public __iter<T> {
public:
    __ss_int counter, size;
    pyseq<T> *p;
    __seqiter<T>();
    __seqiter<T>(pyseq<T> *p);
    T __next__();
};

/* class_ definition */
class class_ : public pyobj {
public:
    str *__name__;
    class_(const char *name);
    str *__repr__();
    __ss_bool __eq__(pyobj *c);
};

/* object definition */
class object : public pyobj {
public:
    object();
};

/* generic min/max functions */
template<class T> T ___max(int n, int total, T t1) {
    return t1;
}

template<class T> T ___max(int n, int total, T t1, T t2) {
    return (t1>t2)?t1:t2;
}

template<class T> T ___max(int n, int total, T t1, T t2, T t3) {
    T m = (t1>t2)?t1:t2;
    return (t3>m)?t3:m;
}

template<class T> T ___min(int n, int total, T t1, T t2) {
    return (t1<t2)?t1:t2;
}

template<class T> T ___min(int n, int total, T t1, T t2, T t3) {
    T m = (t1<t2)?t1:t2;
    return (t3<m)?t3:m;
}

/* slicing */
void slicenr(__ss_int x, __ss_int &l, __ss_int &u, __ss_int &s, __ss_int len);

/* tuple unpacking */
template<class T> void __unpack_check(T t, int expected) {
    if(len(t) > (__ss_int)expected)
        throw new ValueError(new str("too many values to unpack"));
    else if(len(t) < (__ss_int)expected)
        throw new ValueError(new str("not enough values to unpack"));
}

/* Index translation */
template<class T> __ss_int __mods(__ss_int a, T b) {
    __ss_int m = a % b;
    if (m < 0) m += b;
    return m;
}

template<class T> __ss_int __divs(__ss_int a, T b) {
    return (a - __mods(a, b))/b;
}

/* string joining */
template<class T> str *__join_helper(str *sep, T begin, T end) {
    std1::stringstream ss;
    int i = 0;
    while(begin != end) {
        if(i != 0)
            ss << sep->c_str();
        ss << (*begin)->c_str();
        ++i;
        ++begin;
    }
    return new str(ss.str());
}

/* template implementations */
template<class T> inline __iter<T> *pyiter<T>::for_in_init() {
    return this->__iter__();
}

template<class T> inline bool pyiter<T>::for_in_has_next(__iter<T> *iter) {
    iter->__result = iter->__get_next();
    return not iter->__stop_iteration;
}

template<class T> inline T pyiter<T>::for_in_next(__iter<T> *iter) {
    return iter->__result;
}

template<class T> inline size_t pyseq<T>::for_in_init() {
    return 0;
}

template<class T> inline bool pyseq<T>::for_in_has_next(size_t i) {
    return (__ss_int)i < __len__();
}

template<class T> inline T pyseq<T>::for_in_next(size_t &i) {
    __ss_int pos = (__ss_int)i;
    i++;
    return __getitem__(pos);
}

/* Iterator methods */
template<class T> __iter<T> *__iter<T>::__iter__() {
    __stop_iteration = false;
    return this;
}

template<class T> T __iter<T>::__next__() {
    __result = this->__get_next();
    if(__stop_iteration)
        throw new StopIteration();
    return __result;
}

template<class T> T __iter<T>::__get_next() {
    try {
        __result = this->__next__();
    } catch (StopIteration *) {
        __stop_iteration = true;
    }
    return __result;
}

/* Sequence iterator implementations */
template<class T> __seqiter<T>::__seqiter() {}

template<class T> __seqiter<T>::__seqiter(pyseq<T> *seq) {
    this->p = seq;
    size = seq->__len__();
    counter = 0;
}

template<class T> T __seqiter<T>::__next__() {
    if(counter==size)
        throw new StopIteration();
    return p->__getitem__(counter++);
}

/* for loop macros */
#define FOR_IN(e,p,d1,d2,d3) \
    __##d1 = p; \
    __##d3 = __##d1->for_in_init(); \
    while(__##d1->for_in_has_next(__##d3)) { \
        e = __##d1->for_in_next(__##d3);

#define END_FOR }

/* with statement */
template<class T> class __With {
public:
    __With(T expr) : _expr(expr) {
        _expr->__enter__();
    }
    ~__With() {
        _expr->__exit__();
    }
    operator T() const {
        return _expr;
    }
private:
    T _expr;
};

#define WITH(e, n) { __With<decltype(e)> __with##n(e)
#define WITH_VAR(e, v, n) { __With<decltype(e)> __with##n(e); decltype(e) v = __with##n;
#define END_WITH }

/* boolean operations */
#define __OR(a, b, t) ((___bool(__ ## t = a))?(__ ## t):(b))
#define __AND(a, b, t) ((!___bool(__ ## t = a))?(__ ## t):(b))
#define __NOT(x) (__mbool(!(x)))

/* collection implementations */
template <class K, class V>
using __GC_DICT = std1::unordered_map<K, V, ss_hash<K>, ss_eq<K>, gc_allocator< std1::pair<K const, V> > >;

template <class T>
using __GC_SET = std1::unordered_set<T, ss_hash<T>, ss_eq<T>, gc_allocator< T > >;

/* wrapper functions */
template<class T> static inline int __wrap(T a, __ss_int i) {
    __ss_int l = len(a);
#ifndef __SS_NOWRAP
    if(unlikely(i<0)) i += l;
#endif
#ifndef __SS_NOBOUNDS
    if(unlikely(i<0 || i>= l))
        __throw_index_out_of_range();
#endif
    return i;
}

#ifdef __GNUC__
#define unlikely(x)       __builtin_expect((x), 0)
#else
#define unlikely(x)    (x)
#endif

/* pyiter contains implementation */
template<class T> inline __ss_bool pyiter<T>::__contains__(T t) {
    T e;
    typename pyiter<T>::for_in_loop __3;
    int __2;
    pyiter<T> *__1;
    FOR_IN(e,this,1,2,3)
        if(__eq(e,t))
            return __mbool(true);
    END_FOR
    return __mbool(false);
}

/* pyseq cmp implementation */
template<class T> __ss_int pyseq<T>::__cmp__(pyobj *p) {
    if (!p) return 1;
    pyseq<T> *b = (pyseq<T> *)p;
    int i, cmp;
    int mnm = ___min(2, 0, this->__len__(), b->__len__());
    for(i = 0; i < mnm; i++) {
        cmp = __cmp(this->__getitem__(i), b->__getitem__(i));
        if(cmp)
            return cmp;
    }
    return __cmp(this->__len__(), b->__len__());
}

/* helper macros */
#define ASSERT(x, y) if(!(x)) throw new AssertionError(y)

/* initialization */
void __init();
void __start(void (*initfunc)());
void __ss_exit(int code=0);

#include "builtin/bool.hpp"
#include "builtin/exception.hpp"
#include "builtin/extmod.hpp"
#include "builtin/tuple.hpp"
#include "builtin/function.hpp"
#include "builtin/list.hpp"
#include "builtin/bytes.hpp"
#include "builtin/math.hpp"
#include "builtin/dict.hpp"
#include "builtin/set.hpp"
#include "builtin/file.hpp"
#include "builtin/format.hpp"
#include "builtin/complex.hpp"
#include "builtin/copy.hpp"

} // namespace __shedskin__
#endif