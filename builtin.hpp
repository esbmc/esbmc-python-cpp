#ifndef BUILTIN_HPP 
#define BUILTIN_HPP

#include <string>

// Basic type definitions 
typedef unsigned long size_t;
#ifndef NULL 
#define NULL 0 
#endif

namespace shedskin {
    // Forward declarations
    class str;
    class pyobj;
    class class_;

    // Core class type definition
    class class_ {
    public:
        str* __name__;
        class_(const char* name);
    };

    // Class pointers declarations - need to be before exception classes
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

    // Core types that need to be available before dict.hpp
    class pyobj { 
    public: 
        class_* __class__; 
        virtual ~pyobj() {} 
        virtual str* __str__() { return NULL; }
    };

    // Basic class definitions needed
    class str : public pyobj { 
    public: 
        char* unit;
        str(const char* s) : unit(const_cast<char*>(s)) { __class__ = NULL; } 
        virtual ~str() {} 
        virtual str* __str__() { return this; }
    };

    // Character cache - must be defined before use
    extern str* __char_cache[256];

    // Core type definitions
    typedef long long __ss_int;
    typedef double __ss_float;
    struct __ss_bool {
        bool value;
        __ss_bool() : value(false) {}
        __ss_bool(bool b) : value(b) {}
        operator bool() const { return value; }
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

    class KeyError : public Exception {
    public:
        KeyError() { __class__ = cl_keyerror; }
        KeyError(str* msg) : Exception(msg) { __class__ = cl_keyerror; }
    };

    class StopIteration : public Exception {
    public:
        StopIteration() { __class__ = cl_stopiteration; }
        StopIteration(str* msg) : Exception(msg) { __class__ = cl_stopiteration; }
    };

    class AssertionError : public Exception {
    public:
        AssertionError() { __class__ = cl_assertionerror; }
        AssertionError(str* msg) : Exception(msg) { __class__ = cl_assertionerror; }
    };

    class TypeError : public Exception {
    public:
        TypeError() { __class__ = cl_typeerror; }
        TypeError(str* msg) : Exception(msg) { __class__ = cl_typeerror; }
    };

    template<class T1, class T2> class tuple2;
    template<class T> class __iter;

    // Forward declarations for dict.hpp
    template<class K, class V> class dict;
    template<class K, class V> class __dictiterkeys;
    template<class K, class V> class __dictitervalues;
    template<class K, class V> class __dictiteritems;
    template<class K, class V> struct dict_entry;

    // Global constants
    extern __ss_bool True;
    extern __ss_bool False;

    // Basic helper functions
    template<typename T> bool __eq(T a, T b) { return a == b; }
    template<typename T> bool __ne(T a, T b) { return !__eq(a, b); }
    inline __ss_bool ___bool(__ss_bool b) { return b; }
    inline __ss_bool __mbool(bool b) { return __ss_bool(b); }

    // Print function and helpers
    void print(str* s);
    
    // Primary template for repr
    template<typename T>
    str* repr(T* t) { return t->__str__(); }

    template<typename T>
    str* repr(T t) { return repr(&t); }

    // Specializations for specific types
    template<>
    inline str* repr<__ss_int>(__ss_int t) { 
        return new str(std::to_string(t).c_str()); 
    }

    template<>
    inline str* repr<__ss_bool>(__ss_bool t) { 
        return new str(t.value ? "True" : "False"); 
    }

    template<>
    inline str* repr<str*>(str* t) { return t; }

    template<>
    inline str* repr<const char*>(const char* t) { 
        return new str(t); 
    }

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

    // Iterator base class needed by dict
    template<class T> 
    class __iter : public pyobj {
    public:
        virtual T __next__() = 0;
        virtual ~__iter() {}
    };

    // Required initialization functions
    void __init();
    typedef void (*start_type)();
    void __start(start_type func);

    template<class T> inline __ss_int __int(T t) { return static_cast<__ss_int>(t); }
}

// Define assertion handling
#ifndef __SS_NOASSERT
#define ASSERT(x, y) if(!(x)) throw new shedskin::AssertionError(new shedskin::str(#y));
#else
#define ASSERT(x, y)
#endif

// Include full implementations
#include "dict.hpp"
#include "tuple.hpp"

// Namespace aliases
namespace __shedskin__ = shedskin;
namespace __math__ = shedskin;
namespace __time__ = shedskin;

using namespace shedskin;

#endif