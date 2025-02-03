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

namespace shedskin {
    class str;
    class class_;
    template<class T> class __iter;
    template<class T> class list;

    // Forward declare char_cache array
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

    class class_ {
    public:
        str *__name__;
        class_ *__bases__;
        class_() : __name__(new str()), __bases__(NULL) {}
        class_(const char* name) : __name__(new str(name)), __bases__(NULL) {}
        ~class_() { delete __name__; }
    };

    // Basic operations
    bool ___bool(bool b) { return b; }
    bool ___bool(__ss_int i) { return i != 0; }
    bool ___bool(__ss_float f) { return f != 0.0; }
    bool ___bool(str *s) { return s && s->__len__() > 0; }
    
    template<typename T>
    bool ___bool(T* ptr) { return ptr != nullptr; }

    // Iterator support functions
    template<typename T>
    bool all(T* iter) {
        if (!iter) return false;
        bool result = true;
        while (!iter->__stop_iteration) {
            auto val = iter->__get_next();
            if (!iter->__stop_iteration && !___bool(val)) {
                result = false;
                break;
            }
        }
        return result;
    }

    template<typename T>
    bool any(T* iter) {
        if (!iter) return false;
        while (!iter->__stop_iteration) {
            auto val = iter->__get_next();
            if (!iter->__stop_iteration && ___bool(val)) {
                return true;
            }
        }
        return false;
    }

    // Length functions
    __ss_int len(str* s) { return s ? s->__len__() : 0; }
    
    template<typename T>
    __ss_int len(list<T>* l) { return l ? l->__len__() : 0; }

    // Comparison functions
    bool __eq(pyobj* a, pyobj* b) {
        if (a == b) return true;
        if (!a || !b) return false;
        return a->equals(b);
    }

    bool __eq(char a, const str* b) {
        if (!b || !b->data) return false;
        return a == b->data[0];
    }

    bool __eq(const str* a, char b) { return __eq(b, a); }
    bool __eq(char a, char b) { return a == b; }
    bool __ne(pyobj* a, pyobj* b) { return !__eq(a, b); }

    // Math operations
    __ss_int power(__ss_int base, __ss_int exp) {
        __ss_int result = 1;
        while (exp > 0) {
            if (exp & 1) result *= base;
            base *= base;
            exp >>= 1;
        }
        return result;
    }

    __ss_int __power(__ss_int base, __ss_int exp) { return power(base, exp); }
    
    __ss_int __floordiv(__ss_int a, __ss_int b) {
        if (b == 0) throw std::runtime_error("Division by zero");
        return a / b;
    }
    
    __ss_int __mods(__ss_int a, __ss_int b) {
        if (b == 0) throw std::runtime_error("Modulo by zero");
        return a % b;
    }
    
    __ss_int __divs(__ss_int a, __ss_int b) {
        if (b == 0) throw std::runtime_error("Division by zero");
        return a / b;
    }

    // Type checking
    bool isinstance_bool(bool) { return true; }
    bool isinstance_int(__ss_int) { return true; }
    bool isinstance_float(__ss_float) { return true; }
    bool isinstance_str(str*) { return true; }
    
    bool isinstance(pyobj* obj, class_* cls) {
        if (!obj || !cls) return false;
        class_* curr = obj->__class__;
        while (curr) {
            if (curr == cls) return true;
            curr = curr->__bases__;
        }
        return false;
    }

    // Program initialization
    void __init() {}
    void __start(void (*initfunc)()) { initfunc(); }

} // namespace shedskin

namespace ss = shedskin;

// Required includes - order matters
#include "list.hpp"
#include "dict.hpp"
#include "set.hpp"
#include "string.hpp"
#include "tuple.hpp"

#endif