#ifndef BUILTIN_HPP
#define BUILTIN_HPP

// Basic type definitions
typedef unsigned long size_t;
#ifndef NULL
#define NULL 0
#endif

// Include local implementations
#include "string.hpp"
#include "list.hpp"

// Core types needed by shedskin
namespace __shedskin__ {
    typedef long __ss_int;
    typedef bool __ss_bool;
    
    class pyobj {
    public:
        void* __class__;
        virtual ~pyobj() {}
    };

    class str : public pyobj {
    public:
        str(const char* s) {} // Added constructor for string literals
        virtual ~str() {}
    };

    class class_ : public pyobj {
    public:
        class_(const char* name) {} // Added constructor for name
        virtual ~class_() {}
    };

    // Add initialization functions
    void __init() {}
    typedef void (*start_type)();
    void __start(start_type func) {}
}

// Minimal std namespace with only essential iterator types
namespace std {
    template<typename Container>
    class back_insert_iterator {
    public:
        typedef void difference_type;
        typedef void value_type;
        typedef void pointer;
        typedef void reference;

        explicit back_insert_iterator(Container& c) : container(&c) {}
        
        back_insert_iterator<Container>& operator=(const typename Container::value_type& value) {
            container->push_back(value);
            return *this;
        }
        
        back_insert_iterator<Container>& operator*() { return *this; }
        back_insert_iterator<Container>& operator++() { return *this; }
        back_insert_iterator<Container> operator++(int) { return *this; }

    private:
        Container* container;
    };

    template<typename T>
    class vector {
    public:
        typedef T value_type;
        typedef size_t size_type;
        
        void push_back(const T& value) {}
        size_type size() const { return 0; }
    };
}

// Global operator new declarations using plain size_t
void* operator new(size_t count, void* ptr);
void* operator new[](size_t count, void* ptr);

#endif // BUILTIN_HPP