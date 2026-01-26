#ifndef __SET_HPP
#define __SET_HPP

#include "list.hpp"

namespace shedskin {

template<class T>
class set : public pyobj {
private:
    list<T>* items;

public:
    set() : items(new list<T>()) {}
    
    set(list<T>* init) : items(new list<T>()) {
        if(init) {
            for(__ss_int i = 0; i < len(init); i++) {
                add(init->__getfast__(i));
            }
        }
    }

    void add(const T& value) {
        if(!contains(value)) {
            items->append(value);
        }
    }

    bool contains(const T& value) const {
        for(__ss_int i = 0; i < len(items); i++) {
            if(items->__getfast__(i) == value) return true;
        }
        return false;
    }

    bool __contains__(const T& value) const {
        return contains(value);
    }

    void discard(const T& value) {
        for (__ss_int i = 0; i < len(items); i++) {
            if (items->__getfast__(i) == value) {
                items->__remove__(i);
                return;
            }
        }
    }

    T pop() {
        if (len(items) == 0) {
            throw std::out_of_range("pop from an empty set");
        }
        T value = items->__getfast__(0);
        items->__remove__(0);
        return value;
    }

    __ss_int __len__() const {
        return len(items);
    }

    T __getitem__(__ss_int index) const {
        if(index < 0 || index >= len(items)) return T();
        return items->__getfast__(index);
    }

    class for_in_loop {
        typename list<T>::Iterator it;
        typename list<T>::Iterator end_it;
    public:
        for_in_loop() : it(nullptr), end_it(nullptr) {}
        for_in_loop(set<T>& s) : it(s.items->begin()), end_it(s.items->end()) {}
        bool __next__(T& ref) {
            if (it != end_it) {
                ref = *it;
                ++it;
                return true;
            }
            return false;
        }
    };

    ~set() {
        delete items;
    }
};

} // namespace shedskin

#endif
