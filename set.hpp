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

    __ss_int __len__() const {
        return len(items);
    }

    T __getitem__(__ss_int index) const {
        if(index < 0 || index >= len(items)) return T();
        return items->__getfast__(index);
    }

    ~set() {
        delete items;
    }
};

} // namespace shedskin

#endif
