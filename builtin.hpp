#ifndef BUILTIN_HPP
#define BUILTIN_HPP

#include <string>
// Forward declare time.hpp instead of including it
namespace shedskin_time { class struct_time; }

// Basic type definitions 
typedef unsigned long size_t;
#ifndef NULL 
#define NULL 0 
#endif

namespace shedskin {
    // Core type definitions - must be before namespace definitions
    typedef long long __ss_int;
    typedef double __ss_float;
    struct __ss_bool {
        bool value;
        __ss_bool() : value(false) {}
        __ss_bool(bool b) : value(b) {}
        operator bool() const { return value; }
    };

    // Forward declarations
    class str;
    class pyobj;
    class class_;
    template<class T1, class T2> class tuple2;
    template<class T> class list;
    template<class T> class __iter;
    template<class K, class V> class dict;

    // Core class type definition
    class class_ {
    public:
        str* __name__;
        class_(const char* name);
    };

    // Class pointers declarations
    extern class_* cl_class_;
    extern class_* cl_none;
    extern class_* cl_baseexception;
    extern class_* cl_exception;
    extern class_* cl_valueerror;
    extern class_* cl_keyerror;
    extern class_* cl_stopiteration;
    extern class_* cl_assertionerror;
    extern class_* cl_typeerror;
    extern class_* cl_dict;
    extern class_* cl_tuple;
    extern class_* cl_list;

    // Core types
    class pyobj { 
    public: 
        class_* __class__; 
        virtual ~pyobj() {} 
        virtual str* __str__() { return NULL; }
    };

    class str : public pyobj { 
    public: 
        char* unit;
        str(const char* s) : unit(const_cast<char*>(s)) { __class__ = NULL; } 
        virtual ~str() {} 
        virtual str* __str__() { return this; }
        str* operator+(const str* other) {
            return new str(unit); // Simplified for now
        }
        str* operator+(const char* other) {
            return new str(unit); // Simplified for now
        }
    };

    // Exception hierarchy
    class BaseException : public pyobj {
    public:
        str* message;
        BaseException() : message(NULL) { __class__ = cl_baseexception; }
        BaseException(str* msg) : message(msg) { __class__ = cl_baseexception; }
        virtual ~BaseException() {}
        virtual str* __str__() { return message ? message : new str(""); }
    };

    class Exception : public BaseException {
    public:
        Exception() { __class__ = cl_exception; }
        Exception(str* msg) : BaseException(msg) { __class__ = cl_exception; }
    };

    class ValueError : public Exception {
    public:
        ValueError() { __class__ = cl_valueerror; }
        ValueError(str* msg) : Exception(msg) { __class__ = cl_valueerror; }
    };

    class AssertionError : public Exception {
    public:
        AssertionError() { __class__ = cl_assertionerror; }
        AssertionError(str* msg) : Exception(msg) { __class__ = cl_assertionerror; }
    };

    // Tuple class definition
    template<class T1, class T2>
    class tuple2 : public pyobj {
    public:
        T1 first;
        T2 second;
        int size;
        
        tuple2() : size(0), first(), second() {
            this->__class__ = NULL;
        }
        
        tuple2(__ss_int n, T1 t1, T2 t2) : size(n), first(t1), second(t2) {
            this->__class__ = cl_tuple;
        }
        
        T1 __getfirst__() { 
            return first; 
        }
        
        T2 __getsecond__() { 
            return second; 
        }
        
        __ss_int __len__() { 
            return 2; 
        }
        
        __ss_bool __eq__(pyobj* p) {
            tuple2<T1,T2>* b = (tuple2<T1,T2>*)p;
            return __eq(first, b->first) && __eq(second, b->second);
        }
        
        str* __repr__() {
            return nullptr;  // Simplified repr - only used for debug
        }
    };

    // Character cache
    extern str* __char_cache[256];

    // Global constants
    extern __ss_bool True;
    extern __ss_bool False;

    // Helper functions
    template<typename T> bool __eq(T a, T b) { return a == b; }
    template<typename T> bool __ne(T a, T b) { return !__eq(a, b); }
    inline __ss_bool ___bool(__ss_bool b) { return b; }
    inline __ss_bool __mbool(bool b) { return __ss_bool(b); }

    /* and, or, not logic macros */
    #define __OR(a, b, t) ((___bool(__ ## t = a))?(__ ## t):(b))
    #define __AND(a, b, t) ((!___bool(__ ## t = a))?(__ ## t):(b))
    #define __NOT(x) (__mbool(!(x)))

    // Print and repr functions
    void print(str* s);
    
    template<typename T>
    str* repr(T* t) { 
        if (t == NULL) return new str("None");
        return t->__str__(); 
    }

    template<typename T>
    str* repr(T t) { return repr(&t); }

    // Specializations for built-in types
    template<>
    inline str* repr<__ss_int>(__ss_int t) { 
        return new str(std::to_string(t).c_str()); 
    }

    template<>
    inline str* repr<__ss_float>(__ss_float t) {
        return new str(std::to_string(t).c_str());
    }

    template<>
    inline str* repr<__ss_bool>(__ss_bool t) { 
        return new str(t.value ? "True" : "False"); 
    }

    template<>
    inline str* repr<str*>(str* t) { return t; }

    template<typename T>
    void print(T t) {
        print(repr(t));
    }

    template<typename T, typename... Args>
    void print(T t, Args... args) {
        print(t);
        print(new str(" "));
        print(args...);
    }

    // For loop macros
    #define FOR_IN(item, container, counter, dir, size) { \
        counter = 0; \
        while(counter < container->__size) { \
            item = container->units[counter]; \
            counter++;

    #define END_FOR }}

    // Define assertion handling
    #ifndef __SS_NOASSERT
    #define ASSERT(x, y) if(!(x)) throw new shedskin::AssertionError(new shedskin::str(#y));
    #else
    #define ASSERT(x, y)
    #endif

    // Required initialization functions
    void __init();
    typedef void (*start_type)();
    void __start(start_type func);

} // namespace shedskin

// Include time.hpp after shedskin namespace is defined
#include "time.hpp"

// Namespace aliases
namespace __shedskin__ = shedskin;
namespace __math__ = shedskin;
namespace __time__ = shedskin_time;

#include "dict.hpp"  // Include dictionary implementation

#endif