#ifndef SS_DICT_HPP
#define SS_DICT_HPP

#include "builtin.hpp"

namespace shedskin {

// Dict implementation is kept in the same namespace as the forward declarations
template<class K, class V> 
struct dict_entry {
    K key;
    V value;
    dict_entry *next;
    dict_entry(K k, V v) : key(k), value(v), next(nullptr) {}
};

template<class K, class V>
class dict : public pyobj {
private:
    dict_entry<K,V> *entries;
    size_t count;

public:
    dict() : entries(nullptr), count(0) {
        __class__ = NULL;
    }

    // Constructor for initializing with tuples
    template<class... Args>
    dict(int size, Args... args) : entries(nullptr), count(0) {
        __class__ = NULL;
        (insert_tuple(args), ...);
    }

    template<class T>
    void insert_tuple(tuple2<K,V>* t) {
        __setitem__(t->first, t->second);
    }

    ~dict() {
        clear();
    }

    void *__setitem__(K key, V value) {
        dict_entry<K,V> *entry = find_entry(key);
        if (entry) {
            entry->value = value;
        } else {
            dict_entry<K,V> *new_entry = new dict_entry<K,V>(key, value);
            new_entry->next = entries;
            entries = new_entry;
            count++;
        }
        return NULL;
    }

    V __getitem__(K key) {
        dict_entry<K,V> *entry = find_entry(key);
        if (!entry) {
            throw "KeyError";
        }
        return entry->value;
    }

    void *__delitem__(K key) {
        if (!entries) {
            throw "KeyError";
        }

        if (__eq(entries->key, key)) {
            dict_entry<K,V> *temp = entries;
            entries = entries->next;
            delete temp;
            count--;
            return NULL;
        }

        dict_entry<K,V> *current = entries;
        while (current->next) {
            if (__eq(current->next->key, key)) {
                dict_entry<K,V> *temp = current->next;
                current->next = current->next->next;
                delete temp;
                count--;
                return NULL;
            }
            current = current->next;
        }
        throw "KeyError";
    }

    __ss_int __len__() const {
        return count;
    }

    __ss_bool __contains__(K key) {
        return find_entry(key) != nullptr;
    }

    void *clear() {
        while (entries) {
            dict_entry<K,V> *temp = entries;
            entries = entries->next;
            delete temp;
        }
        count = 0;
        return NULL;
    }

    dict<K,V> *copy() {
        dict<K,V> *new_dict = new dict<K,V>();
        dict_entry<K,V> *current = entries;
        while (current) {
            new_dict->__setitem__(current->key, current->value);
            current = current->next;
        }
        return new_dict;
    }

    V get(K key) {
        dict_entry<K,V> *entry = find_entry(key);
        return entry ? entry->value : V();
    }

    V get(K key, V default_value) {
        dict_entry<K,V> *entry = find_entry(key);
        return entry ? entry->value : default_value;
    }

    __dictiterkeys<K,V> *keys() {
        return new __dictiterkeys<K,V>(this);
    }

    __dictitervalues<K,V> *values() {
        return new __dictitervalues<K,V>(this);
    }

    __dictiteritems<K,V> *items() {
        return new __dictiteritems<K,V>(this);
    }

private:
    dict_entry<K,V> *find_entry(K key) {
        dict_entry<K,V> *current = entries;
        while (current) {
            if (__eq(current->key, key)) {
                return current;
            }
            current = current->next;
        }
        return nullptr;
    }
};

// Iterator implementations
template<class K, class V>
class __dictiterkeys : public __iter<K> {
protected:
    dict<K,V> *dict_ptr;
    dict_entry<K,V> *current;

public:
    __dictiterkeys(dict<K,V> *d) : dict_ptr(d), current(d->entries) {}
    
    K __next__() {
        if (!current) {
            throw "StopIteration";
        }
        K key = current->key;
        current = current->next;
        return key;
    }
};

template<class K, class V>
class __dictitervalues : public __iter<V> {
protected:
    dict<K,V> *dict_ptr;
    dict_entry<K,V> *current;

public:
    __dictitervalues(dict<K,V> *d) : dict_ptr(d), current(d->entries) {}
    
    V __next__() {
        if (!current) {
            throw "StopIteration";
        }
        V value = current->value;
        current = current->next;
        return value;
    }
};

template<class K, class V>
class __dictiteritems : public __iter<tuple2<K,V>*> {
protected:
    dict<K,V> *dict_ptr;
    dict_entry<K,V> *current;

public:
    __dictiteritems(dict<K,V> *d) : dict_ptr(d), current(d->entries) {}
    
    tuple2<K,V> *__next__() {
        if (!current) {
            throw "StopIteration";
        }
        tuple2<K,V> *tuple = new tuple2<K,V>(2, current->key, current->value);
        current = current->next;
        return tuple;
    }
};

} // namespace shedskin

#endif // SS_DICT_HPP