#ifndef __LIST_HPP
#define __LIST_HPP

#include "builtin.hpp"
#include <list>

namespace shedskin {

static __ss_bool __result;

template<typename T>
T __zero() { return T(); }

template<typename T>
class list : public pyobj {
public:
    typedef unsigned int size_type;
    T _list[20];  // Fixed size array like ESBMC's implementation
    size_type _size;

    // Constructors
    list() : _size(0) {}
    
    list(size_type count, const T& value) : _size(0) {
        for(size_type i = 0; i < count; ++i) {
            _list[i] = value;
        }
        _size = count;
    }

    template<typename... Args>
    list(size_type count, Args... args) : _size(0) {
        T arr[] = {static_cast<T>(args)...};
        for(size_type i = 0; i < sizeof...(args); ++i) {
            _list[i] = arr[i];
        }
        _size = sizeof...(args);
    }

    list(const list<T>& other) : _size(0) {
        for(size_type i = 0; i < other._size; ++i) {
            _list[i] = other._list[i];
        }
        _size = other._size;
    }

    // Python-style operations
    __ss_int __len__() const { 
        return _size; 
    }
    
    T __getitem__(__ss_int index) const {
        if (index < 0) index = _size + index;
        if (index < 0 || index >= _size) return T();
        return _list[index];
    }
    
    T __getfast__(__ss_int index) const {
        if (index < 0 || index >= _size) return T();
        return _list[index];
    }
    
    void __setitem__(__ss_int index, const T& value) {
        if (index < 0) index = _size + index;
        if (index < 0 || index >= _size) return;
        _list[index] = value;
    }

    __ss_bool __contains__(const T& value) const {
        for(size_type i = 0; i < _size; ++i) {
            if (_list[i] == value)
                return True;
        }
        return False;
    }

    list<T>* __add__(list<T>* other) const {
        list<T>* result = new list<T>(*this);
        for(size_type i = 0; i < other->_size; ++i) {
            result->_list[result->_size + i] = other->_list[i];
        }
        result->_size += other->_size;
        return result;
    }

    list<T>* __mul__(__ss_int n) const {
        list<T>* result = new list<T>();
        for(__ss_int i = 0; i < n; ++i) {
            for(size_type j = 0; j < _size; ++j) {
                result->_list[i * _size + j] = _list[j];
            }
        }
        result->_size = _size * n;
        return result;
    }

    list<T>* __slice__(__ss_int length, __ss_int start, __ss_int stop, __ss_int step) const {
        list<T>* result = new list<T>();
        if (start < 0) start = _size + start;
        if (stop < 0) stop = _size + stop;
        
        if (start < 0) start = 0;
        if (stop > _size) stop = _size;
        
        size_type j = 0;
        for(__ss_int i = start; i < stop; i += (step ? step : 1)) {
            if (i >= 0 && i < _size) {
                result->_list[j++] = _list[i];
            }
        }
        result->_size = j;
        return result;
    }

    void append(const T& value) {
        if (_size < 20) {  // Max size check
            _list[_size++] = value;
        }
    }

    void extend(list<T>* other) {
        for(size_type i = 0; i < other->_size && _size < 20; ++i) {
            append(other->_list[i]);
        }
    }

    T pop(__ss_int index = -1) {
        if (index < 0) index = _size + index;
        if (index < 0 || index >= _size) return T();
        T value = _list[index];
        for(size_type i = index; i < _size - 1; ++i) {
            _list[i] = _list[i + 1];
        }
        --_size;
        return value;
    }

    void insert(__ss_int index, const T& value) {
        if (_size >= 20) return;  // Max size check
        if (index < 0) index = _size + index;
        if (index < 0) index = 0;
        if (index > _size) index = _size;
        
        for(size_type i = _size; i > index; --i) {
            _list[i] = _list[i - 1];
        }
        _list[index] = value;
        ++_size;
    }

    void remove(const T& value) {
        for(size_type i = 0; i < _size; ++i) {
            if (_list[i] == value) {
                for(size_type j = i; j < _size - 1; ++j) {
                    _list[j] = _list[j + 1];
                }
                --_size;
                return;
            }
        }
    }

    __ss_int count(const T& value) const {
        __ss_int count = 0;
        for(size_type i = 0; i < _size; ++i) {
            if (_list[i] == value) ++count;
        }
        return count;
    }

    void clear() {
        _size = 0;
    }

    void reverse() {
        for(size_type i = 0; i < _size / 2; ++i) {
            T temp = _list[i];
            _list[i] = _list[_size - 1 - i];
            _list[_size - 1 - i] = temp;
        }
    }

    void sort() {
        for(size_type i = 0; i < _size - 1; ++i) {
            for(size_type j = 0; j < _size - i - 1; ++j) {
                if (_list[j] > _list[j + 1]) {
                    T temp = _list[j];
                    _list[j] = _list[j + 1];
                    _list[j + 1] = temp;
                }
            }
        }
    }

    class for_in_loop {
        const list<T>* lst;
        size_type current;
    public:
        for_in_loop() : lst(0), current(0) {}
        explicit for_in_loop(const list<T>& l) : lst(&l), current(0) {}
        
        bool __next__(T& ref) {
            if (current < lst->_size) {
                ref = lst->_list[current++];
                return true;
            }
            return false;
        }
    };

    bool operator==(const list<T>& other) const {
        if (_size != other._size) return false;
        for(size_type i = 0; i < _size; ++i) {
            if (!(_list[i] == other._list[i]))
                return false;
        }
        return true;
    }
};

// Helper functions
template<typename Container>
__ss_bool all(Container* lst) {
    if (!lst) return False;
    return True;
}

template<typename T>
__ss_int len(list<T>* lst) {
    return lst ? lst->__len__() : 0;
}

template<typename T>
list<T>* sorted(list<T>* lst, __ss_int start=0, __ss_int stop=0, __ss_int step=0) {
    if (!lst) return new list<T>();
    list<T>* result = new list<T>(*lst);
    result->sort();
    return result;
}

template<typename T>
__ss_bool __eq(list<T>* a, list<T>* b) {
    if (!a || !b) return False;
    if (a == b) return True;
    return *a == *b;
}

} // namespace shedskin

#endif
