#ifndef BUILTIN_HPP
#define BUILTIN_HPP

// Basic type definitions
typedef unsigned long size_t;
#ifndef NULL
#define NULL 0
#endif

// Core types needed by shedskin
namespace shedskin {
    typedef long __ss_int;
    typedef bool __ss_bool;
    typedef double __ss_float;
    
    // Core functions
    inline __ss_bool __mbool(bool b) { return b; }
    inline __ss_bool ___bool(bool b) { return b; }  // Added alias
    template<typename T> bool __eq(T a, T b) { return a == b; }
    template<typename T> bool __ne(T a, T b) { return a != b; }  // Added not equal operator


    // Define pyobj fully
    class pyobj {
    public:
        void* __class__;
        virtual ~pyobj() {}
    };

    class str : public pyobj {
    public:
        str(const char* s) {}
        virtual ~str() {}
    };

    class class_ : public pyobj {
    public:
        class_(const char* name) {}
        virtual ~class_() {}
    };

    // The common tuple2 definition
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

// Provide aliases for generated code
namespace __shedskin__ = shedskin;
namespace __math__ = shedskin;
namespace __time__ = shedskin;

// Simplified assertion macro
#define ASSERT(condition, message) if(!(condition)) { throw "Assertion failed"; }

#endif // BUILTIN_HPP