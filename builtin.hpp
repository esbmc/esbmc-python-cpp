#ifndef BUILTIN_HPP 
#define BUILTIN_HPP

// Basic type definitions 
typedef unsigned long size_t;
#ifndef NULL 
#define NULL 0 
#endif

// Define assertion handling
class AssertionError {
public:
    const char* message;
    AssertionError(const char* msg) : message(msg) {}
};

#ifndef __SS_NOASSERT
#define ASSERT(x, y) if(!(x)) throw new AssertionError(#y);
#else
#define ASSERT(x, y)
#endif

namespace shedskin {
    // Core types that need to be available before dict.hpp
    class pyobj { 
    public: 
        void* __class__; 
        virtual ~pyobj() {} 
    };

    // Basic class definitions needed
    class str : public pyobj { 
    public: 
        char* unit;
        str(const char* s) : unit(const_cast<char*>(s)) { __class__ = NULL; } 
        virtual ~str() {} 
    };

    template<class T1, class T2> class tuple2;
    template<class T> class __iter;

    // Forward declarations for dict.hpp
    template<class K, class V> class dict;
    template<class K, class V> class __dictiterkeys;
    template<class K, class V> class __dictitervalues;
    template<class K, class V> class __dictiteritems;
    template<class K, class V> struct dict_entry;

    // Character cache
    extern str* __char_cache[256];

    // Core type definitions
    typedef long long __ss_int;
    typedef double __ss_float;
    typedef bool __ss_bool;

    // Global constants
    extern __ss_bool True;
    extern __ss_bool False;

    // Basic functions needed
    template<typename T> bool __eq(T a, T b) { return a == b; }
    inline __ss_bool ___bool(__ss_bool b) { return b; }
    void print(str* s);

    // Iterator base class needed by dict
    template<class T> 
    class __iter : public pyobj {
    public:
        virtual T __next__() = 0;
        virtual ~__iter() {}
    };

    // Required initialization functions
    void __init() {}
    typedef void (*start_type)();
    void __start(start_type func) {}

    template<class T> inline __ss_int __int(T t) { return static_cast<__ss_int>(t); }
}

// Include full implementations
#include "dict.hpp"
#include "tuple.hpp"

// Namespace aliases
namespace __shedskin__ = shedskin;
namespace __math__ = shedskin;
namespace __time__ = shedskin;

using namespace shedskin;

#endif