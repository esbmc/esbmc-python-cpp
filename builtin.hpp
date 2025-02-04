#ifndef SS_BUILTIN_HPP
#define SS_BUILTIN_HPP
#include <cstddef>
#include <string.h>
#include <iostream>
#include <stdexcept>

#ifndef NULL 
#define NULL 0
#endif

typedef int __ss_int;
typedef double __ss_float;
typedef bool __ss_bool;
static const bool True = true;
static const bool False = false;

#define ASSERT(x, msg) __ESBMC_assert(x, "Assertion Failed")
#define __NOT(x) (!(x))
#define __AND(a, b, t) ((!___bool(__ ## t = a))?(__ ## t):(b))

#define FAST_FOR(var, start, stop, step, zero, dir) \
    for(__ss_int var = (start); \
        dir ? (var < (stop)) : (var > (stop)); \
        var = var + (step))

#define END_FOR

namespace shedskin {
    class str;
    class class_;

    // Forward declare char_cache array - definition will be in cpp
    extern str* __char_cache[256];
    
    class pyobj {
    public:
        class_ *__class__;
        pyobj() : __class__(NULL) {}
        virtual ~pyobj() {}
        virtual bool equals(const pyobj* other) const { 
            return this == other; 
        }
    };

    class str : public pyobj {
    public:
        const char* data;
        str() : data(NULL) {}
        str(const char* s) : data(s) {}
        const char* c_str() const { return data; }
        
        virtual bool equals(const pyobj* other) const override {
            const str* other_str = dynamic_cast<const str*>(other);
            if (!other_str) return false;
            if (!data || !other_str->data) return false;
            return strcmp(data, other_str->data) == 0;
        }

        str* strip() const;
        str* upper() const;
        str* lower() const;
        str* replace(const str* old_str, const str* new_str) const;
        str* format() const;
        str* __add__(const str* other) const;

        char __getfast__(__ss_int i) const { 
            return data[i]; 
        }

        __ss_int __len__() const { 
            return data ? strlen(data) : 0; 
        }

        str* __getitem__(__ss_int i) const;
    };

    __ss_int len(str* s) {
        return s->__len__();
    }

    class class_ {
    public:
        str *__name__;
        class_ *__bases__;
        class_() : __name__(new str()), __bases__(NULL) {}
        class_(const char* name) : __name__(new str(name)), __bases__(NULL) {}
        ~class_() { delete __name__; }
    };

    __ss_bool isinstance(pyobj* obj, class_* cls) {
        if (!obj || !cls) return false;
        class_* curr = obj->__class__;
        while (curr) {
            if (curr == cls) return true;
            curr = curr->__bases__;
        }
        return false;
    }

    bool isinstance_bool(bool val) { return true; }
    bool isinstance_int(__ss_int val) { return true; }
    bool isinstance_float(__ss_float val) { return true; }
    bool isinstance_str(str *s) { return true; }

    inline void print() {
       // std::cout << std::endl;
    }

    template<typename T>
    void print(const T& value) {
       // std::cout << value << std::endl;
    }

    template<typename T1, typename T2>
    void print(const T1& value1, const T2& value2) {
       // std::cout << value1 << value2 << std::endl;
    }

    template<typename... Args>
    void print(const Args&... args) {
        //(std::cout << ... << args) << std::endl;
    }

    inline __ss_int power(__ss_int base, __ss_int exp) {
        __ss_int result = 1;
        while (exp > 0) {
            if (exp & 1)
                result *= base;
            base *= base;
            exp >>= 1;
        }
        return result;
    }
    
    inline __ss_int __power(__ss_int base, __ss_int exp) {
        return power(base, exp);
    }

    inline bool ___bool(bool b) {
        return b;
    }

    inline bool __eq(pyobj* a, pyobj* b) {
        if (a == b) return true;
        if (!a || !b) return false;
        return a->equals(b);
    }

    inline bool __eq(char a, const str* b) {
        if (!b || !b->data) return false;
        return a == b->data[0];
    }

    inline bool __eq(const str* a, char b) {
        return __eq(b, a);
    }

    bool __eq(char a, char b) {
        return a == b;
    }

    inline bool __ne(pyobj* a, pyobj* b) {
        return !__eq(a, b);
    }

    void __init() {}

    int __int(int value) {
        return value;
    }

    int __floordiv(int a, int b) {
        if (b == 0) {
            throw std::runtime_error("Division by zero");
        }
        return a / b;
    }
    
    inline __ss_int __mods(__ss_int a, __ss_int b) {
        if (b == 0) {
            throw std::runtime_error("Modulo by zero is undefined");
        }
        return a % b;
    }
    
    // Defining __divs to manage whole divisions
    inline __ss_int __divs(__ss_int a, __ss_int b) {
        if (b == 0) {
            std::cerr << "Error: Division by zero detected" << std::endl;
            throw std::runtime_error("Division by zero detected");
        }
        return a / b; // Renvoie le résultat de la division entière
    }

    void __start(void (*initfunc)()) {
        initfunc();
    }

    inline __ss_int __range(__ss_int stop) {
        return stop;
    }

    inline __ss_int __range(__ss_int start, __ss_int stop) {
        return stop;
    }

    inline __ss_int __range(__ss_int start, __ss_int stop, __ss_int step) {
        return stop;
    }
} // namespace shedskin

namespace ss = shedskin;

#include "list.hpp"
#include "dict.hpp"
#include "set.hpp"
#include "string.hpp"
#include "tuple.hpp"
#include "bytes.hpp"
#include "math.hpp"
#include "random.hpp"

#endif
