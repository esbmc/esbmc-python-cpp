#ifndef SS_TUPLE_HPP
#define SS_TUPLE_HPP

#include <type_traits>
#include "utility"
#include "cstddef"
#include "builtin.hpp"

namespace shedskin {

// Exception class for tuple errors
class TypeError : public pyobj {
public:
    shedskin::str* msg;
    TypeError(shedskin::str* message) : msg(message) {}
    virtual ~TypeError() {}
};

// Forward declarations
template<typename T> class tuple;

// Specialization for single-type tuples
template<typename T>
class tuple {
private:
    T* elements;
    std::size_t size;

public:
    tuple() : elements(nullptr), size(0) {}

    tuple(std::size_t count, ...) {
        size = count;
        elements = new T[count];
        
        va_list args;
        va_start(args, count);
        for(std::size_t i = 0; i < count; i++) {
            elements[i] = va_arg(args, T);
        }
        va_end(args);
    }

    tuple(const tuple& other) {
        size = other.size;
        elements = new T[size];
        for(std::size_t i = 0; i < size; i++) {
            elements[i] = other.elements[i];
        }
    }

    ~tuple() {
        delete[] elements;
    }

    T __getfirst__() const { 
        if(size == 0) throw new TypeError(new shedskin::str("Empty tuple"));
        return elements[0];
    }

    T __getsecond__() const {
        if(size < 2) throw new TypeError(new shedskin::str("Tuple has no second element"));
        return elements[1];
    }

    T __getitem__(std::size_t index) const {
        if(index >= size) 
            throw new TypeError(new shedskin::str("Tuple index out of range"));
        return elements[index];
    }

    std::size_t __len__() const { return size; }

    void __setitem__(std::size_t, const T&) {
        throw new TypeError(new shedskin::str("'tuple' object does not support item assignment"));
    }

    bool operator==(const tuple& other) const {
        if(size != other.size) return false;
        for(std::size_t i = 0; i < size; i++) {
            if(elements[i] != other.elements[i]) return false;
        }
        return true;
    }

    bool operator<(const tuple& other) const {
        std::size_t min_size = size < other.size ? size : other.size;
        for(std::size_t i = 0; i < min_size; i++) {
            if(elements[i] < other.elements[i]) return true;
            if(elements[i] > other.elements[i]) return false;
        }
        return size < other.size;
    }
};

// Sorting helper accepting lambdas
template<typename T, typename F>
list<T>* sorted(list<T>* lst, std::size_t start, F key_func, std::size_t step) {
    list<T>* result = new list<T>(*lst);
    size_t size = result->__len__();
    
    for(size_t i = 0; i < size-1; i++) {
        size_t min_idx = i;
        for(size_t j = i+1; j < size; j++) {
            if(key_func(result->__getitem__(j)) < key_func(result->__getitem__(min_idx))) {
                min_idx = j;
            }
        }
        if(min_idx != i) {
            T temp = result->__getitem__(i);
            result->__setitem__(i, result->__getitem__(min_idx));
            result->__setitem__(min_idx, temp);
        }
    }
    return result;
}

} // namespace shedskin

// Min/max functions
template<typename T>
T ___min(std::size_t count, std::size_t index, shedskin::tuple<T>* t) {
    if(!t || t->__len__() == 0) 
        throw new shedskin::TypeError(new shedskin::str("Empty tuple"));
    
    T min_val = t->__getitem__(index);
    for(std::size_t i = index + 1; i < t->__len__(); i++) {
        T curr = t->__getitem__(i);
        if(curr < min_val) min_val = curr;
    }
    return min_val;
}

template<typename T>
T ___max(std::size_t count, std::size_t index, shedskin::tuple<T>* t) {
    if(!t || t->__len__() == 0) 
        throw new shedskin::TypeError(new shedskin::str("Empty tuple"));
    
    T max_val = t->__getitem__(index);
    for(std::size_t i = index + 1; i < t->__len__(); i++) {
        T curr = t->__getitem__(i);
        if(curr > max_val) max_val = curr;
    }
    return max_val;
}

// Global using declarations
using shedskin::tuple;
using shedskin::TypeError;
using shedskin::sorted;

#endif // SS_TUPLE_HPP
