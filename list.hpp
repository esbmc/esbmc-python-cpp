// list.hpp
#ifndef __LIST_HPP
#define __LIST_HPP

#include "builtin.hpp"
#include <cstdarg>

namespace shedskin {

template<class T> class list;
class str;
class pyobj;

template<class T>
class __iter {
public:
    bool __stop_iteration;
    __iter() : __stop_iteration(false) {}
    virtual ~__iter() {}
    virtual T __get_next() = 0;
};

template<typename T>
class list : public pyobj {
protected:
    T* elements;
    __ss_int capacity;
    __ss_int size_;

    void ensure_capacity(__ss_int required) {
        if (required > capacity) {
            __ss_int new_capacity = (capacity == 0) ? 8 : capacity * 2;
            while (new_capacity < required) new_capacity *= 2;
            
            T* new_elements = new T[new_capacity];
            for (__ss_int i = 0; i < size_; i++) {
                new_elements[i] = elements[i];
            }
            delete[] elements;
            elements = new_elements;
            capacity = new_capacity;
        }
    }

public:
    class for_in_loop {
    private:
        const list<T>* lst;
        __ss_int current;
    public:
        for_in_loop() : lst(nullptr), current(0) {}
        explicit for_in_loop(const list<T>* l) : lst(l), current(0) {}
        
        bool next(T& ref) {
            if (!lst || current >= lst->__len__()) return false;
            ref = lst->__getitem__(current++);
            return true;
        }
    };

    list() : elements(nullptr), capacity(0), size_(0) {}
    
    explicit list(__ss_int count) : elements(new T[count]), capacity(count), size_(count) {
        for (__ss_int i = 0; i < count; i++) elements[i] = T();
    }

    list(__ss_int count, T a1) : elements(new T[count]), capacity(count), size_(count) {
        elements[0] = a1;
        for (__ss_int i = 1; i < count; i++) elements[i] = T();
    }

    list(__ss_int count, T a1, T a2) : elements(new T[count]), capacity(count), size_(count) {
        elements[0] = a1;
        elements[1] = a2;
        for (__ss_int i = 2; i < count; i++) elements[i] = T();
    }

    list(__ss_int count, T a1, T a2, T a3) : elements(new T[count]), capacity(count), size_(count) {
        elements[0] = a1;
        elements[1] = a2;
        elements[2] = a3;
        for (__ss_int i = 3; i < count; i++) elements[i] = T();
    }

    list(__ss_int count, T a1, T a2, T a3, T a4) : elements(new T[count]), capacity(count), size_(count) {
        elements[0] = a1;
        elements[1] = a2;
        elements[2] = a3;
        elements[3] = a4;
        for (__ss_int i = 4; i < count; i++) elements[i] = T();
    }

    list(__ss_int count, T a1, T a2, T a3, T a4, T a5) : elements(new T[count]), capacity(count), size_(count) {
        elements[0] = a1;
        elements[1] = a2;
        elements[2] = a3;
        elements[3] = a4;
        elements[4] = a5;
        for (__ss_int i = 5; i < count; i++) elements[i] = T();
    }

    ~list() { delete[] elements; }

    void append(T item) {
        ensure_capacity(size_ + 1);
        elements[size_++] = item;
    }

    T __getitem__(__ss_int i) const {
        if (i < 0) i += size_;
        if (i < 0 || i >= size_) return T();
        return elements[i];
    }

    T __getfast__(__ss_int i) const {
        return elements[i];
    }

    __ss_int __len__() const { 
        return size_; 
    }
};

// Specialization for __ss_int
template<>
class list<__ss_int> : public list<pyobj*> {
private:
    static pyobj* convert_to_pyobj(__ss_int value) {
        return reinterpret_cast<pyobj*>(value);
    }

public:
    list() : list<pyobj*>() {}
    explicit list(__ss_int count) : list<pyobj*>(count) {}

    list(__ss_int count, __ss_int a1) : list<pyobj*>(count) {
        elements[0] = convert_to_pyobj(a1);
        for (__ss_int i = 1; i < count; i++) elements[i] = nullptr;
    }

    list(__ss_int count, __ss_int a1, __ss_int a2) : list<pyobj*>(count) {
        elements[0] = convert_to_pyobj(a1);
        elements[1] = convert_to_pyobj(a2);
        for (__ss_int i = 2; i < count; i++) elements[i] = nullptr;
    }

    list(__ss_int count, __ss_int a1, __ss_int a2, __ss_int a3) : list<pyobj*>(count) {
        elements[0] = convert_to_pyobj(a1);
        elements[1] = convert_to_pyobj(a2);
        elements[2] = convert_to_pyobj(a3);
        for (__ss_int i = 3; i < count; i++) elements[i] = nullptr;
    }

    list(__ss_int count, __ss_int a1, __ss_int a2, __ss_int a3, __ss_int a4) : list<pyobj*>(count) {
        elements[0] = convert_to_pyobj(a1);
        elements[1] = convert_to_pyobj(a2);
        elements[2] = convert_to_pyobj(a3);
        elements[3] = convert_to_pyobj(a4);
        for (__ss_int i = 4; i < count; i++) elements[i] = nullptr;
    }

    list(__ss_int count, __ss_int a1, __ss_int a2, __ss_int a3, __ss_int a4, __ss_int a5) : list<pyobj*>(count) {
        elements[0] = convert_to_pyobj(a1);
        elements[1] = convert_to_pyobj(a2);
        elements[2] = convert_to_pyobj(a3);
        elements[3] = convert_to_pyobj(a4);
        elements[4] = convert_to_pyobj(a5);
        for (__ss_int i = 5; i < count; i++) elements[i] = nullptr;
    }
};

inline void print_value(str* s) {
    if (s && s->c_str()) printf("%s", s->c_str());
}

inline void print_value(__ss_int n) {
    printf("%d", n);
}

inline void print_value(double d) {
    printf("%g", d);
}

inline void print_value(pyobj* p) {
    if (p) {
        str* s = dynamic_cast<str*>(p);
        if (s) print_value(s);
    }
}

inline void print() {
    printf("\n");
}

template<typename First, typename... Rest>
inline void print(First first, Rest... rest) {
    print_value(first);
    if (sizeof...(rest) > 0) printf(" ");
    print(rest...);
}

} // namespace shedskin

namespace __shedskin__ = shedskin;

#endif