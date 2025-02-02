#ifndef BUILTIN_HPP 
#define BUILTIN_HPP

// Basic type definitions 
typedef unsigned long size_t; 
#ifndef NULL 
#define NULL 0 
#endif

namespace shedskin { 
    // Core type definitions 
    typedef long long __ss_int;
    typedef double __ss_float;
    typedef bool __ss_bool;

    // Global constants
    extern __ss_bool True;
    extern __ss_bool False;

    // Forward declarations for all commonly used types/classes 
    class str; 
    class class_; 
    template<class T> class list; 
    template<class T1, class T2> class tuple2;

    // Operator macros
    #define __OR(a, b, t) ((___bool(__ ## t = a))?(__ ## t):(b))
    #define __AND(a, b, t) ((!___bool(__ ## t = a))?(__ ## t):(b))
    #define __NOT(x) (__mbool(!(x)))

    // Forward declarations from function.hpp 
    template<class T> inline __ss_int __int(T t) { return static_cast<__ss_int>(t); }
    template<class T> inline __ss_float __float(T t) { return static_cast<__ss_float>(t); }
    template<class T> inline str* __str(T t) { return nullptr; }
    template<class T> inline T __abs(T t) { return t < 0 ? -t : t; }
    template<class T> inline __ss_int len(T x) { return 0; }
    
    // Print functions
    void print(str* s);
    template<class... Args> void print(Args... args) {}
    
    // Core functions used across modules 
    inline __ss_bool __mbool(bool b) { return b; } 
    inline __ss_bool ___bool(__ss_bool b) { return b; } 
    template<typename T> bool __eq(T a, T b) { return a == b; } 
    template<typename T> bool __ne(T a, T b) { return a != b; }

    // Basic class definitions 
    class pyobj { 
    public: 
        void* __class__; 
        virtual ~pyobj() {} 
    };

    class str : public pyobj { 
    public: 
        char* unit;  // Changed from string to char* to avoid ambiguity 
        str(const char* s) : unit(const_cast<char*>(s)) {} 
        virtual ~str() {} 
    };

    class class_ : public pyobj { 
    public: 
        class_(const char* name) {} 
        virtual ~class_() {} 
    };

    // Full tuple2 implementation since it's needed everywhere 
    template<class T1, class T2> 
    class tuple2 : public pyobj { 
    public: 
        T1 first; 
        T2 second; 
        int size;

        tuple2() : size(0), first(), second() { 
            __class__ = NULL; 
        }

        tuple2(const T1& f, const T2& s) : size(2), first(f), second(s) { 
            __class__ = NULL; 
        }

        tuple2(int s, const T1& f, const T2& s2) : size(s), first(f), second(s2) { 
            __class__ = NULL; 
        }

        virtual ~tuple2() {} 
    };

    // Initialization functions 
    void __init() {} 
    typedef void (*start_type)(); 
    void __start(start_type func) {} 
}

// Namespace aliases for generated code 
namespace __shedskin__ = shedskin; 
namespace __math__ = shedskin; 
namespace __time__ = shedskin;
using namespace shedskin;

// Simplified assertion macro 
#define ASSERT(condition, message) if(!(condition)) { throw "Assertion failed"; }

#endif // BUILTIN_HPP