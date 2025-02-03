#ifndef SS_DICT_HPP
#define SS_DICT_HPP

#include "builtin.hpp"

namespace shedskin {

template<class K, class V> 
struct dict_entry {
    K key;
    V value;
    dict_entry *next;
    dict_entry(K k, V v) : key(k), value(v), next(nullptr) {}
};

template<class K, class V>
class __dictiterkeys;

template<class K, class V>
class __dictitervalues;

template<class K, class V>
class __dictiteritems;

template<class K, class V>
class dict : public pyobj {
private:
    dict_entry<K,V> *entries;
    __ss_int count;

public:
    dict() : entries(nullptr), count(0) {
        this->__class__ = cl_dict;
    }

    // Constructor for initializing with tuples
    template<class... Args>
    dict(int size, Args... args) : entries(nullptr), count(0) {
        this->__class__ = cl_dict;
        int dummy[] = {(__add_items(args), 0)...};
        (void)dummy;
    }

    ~dict() {
        clear();
    }

    void __add_items(tuple2<K,V>* t) {
        __setitem__(t->__getfirst__(), t->__getsecond__());
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
            throw new ValueError(new str("KeyError"));
        }
        return entry->value;
    }

    void *__delitem__(K key) {
        if (!entries) {
            throw new ValueError(new str("KeyError"));
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
        throw new ValueError(new str("KeyError"));
    }

    __ss_int __len__() {
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
        return new __dictiterkeys<K,V>(entries);
    }

    __dictitervalues<K,V> *values() {
        return new __dictitervalues<K,V>(entries);
    }

    __dictiteritems<K,V> *items() {
        return new __dictiteritems<K,V>(entries);
    }

    __ss_bool __eq__(pyobj *p) {
        dict<K,V> *other = (dict<K,V> *)p;
        if (other->__len__() != this->__len__())
            return False;
        
        dict_entry<K,V> *current = entries;
        while (current) {
            dict_entry<K,V> *other_entry = other->find_entry(current->key);
            if (!other_entry || __ne(other_entry->value, current->value))
                return False;
            current = current->next;
        }
        return True;
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
private:
    dict_entry<K,V> *current;
public:
    __dictiterkeys(dict_entry<K,V> *first) : current(first) {}
    
    K __next__() override {
        if (!current) 
            throw new ValueError(new str("StopIteration"));
        K key = current->key;
        current = current->next;
        return key;
    }
};

template<class K, class V>
class __dictitervalues : public __iter<V> {
private:
    dict_entry<K,V> *current;
public:
    __dictitervalues(dict_entry<K,V> *first) : current(first) {}
    
    V __next__() override {
        if (!current) 
            throw new ValueError(new str("StopIteration"));
        V value = current->value;
        current = current->next;
        return value;
    }
};

template<class K, class V>
class __dictiteritems : public __iter<tuple2<K,V>*> {
private:
    dict_entry<K,V> *current;
public:
    __dictiteritems(dict_entry<K,V> *first) : current(first) {}
    
    tuple2<K,V> *__next__() override {
        if (!current) 
            throw new ValueError(new str("StopIteration"));
        tuple2<K,V> *result = new tuple2<K,V>(2, current->key, current->value);
        current = current->next;
        return result;
    }
};

} // namespace shedskin

#endif // SS_DICT_HPP