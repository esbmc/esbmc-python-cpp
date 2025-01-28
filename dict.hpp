#ifndef __DICT_HPP
#define __DICT_HPP

// Optimized macros for operations in blocks of 4
#define INIT_USED_4(start) \
    used[start] = used[start+1] = used[start+2] = used[start+3] = false;

#define CHECK_SLOT_4(start) \
    if(used[start] && keys[start] == key) return values[start]; \
    if(used[start+1] && keys[start+1] == key) return values[start+1]; \
    if(used[start+2] && keys[start+2] == key) return values[start+2]; \
    if(used[start+3] && keys[start+3] == key) return values[start+3];

#define FIND_EMPTY_4(start) \
    if(!used[start]) { keys[start] = key; used[start] = true; size_++; return values[start]; } \
    if(!used[start+1]) { keys[start+1] = key; used[start+1] = true; size_++; return values[start+1]; } \
    if(!used[start+2]) { keys[start+2] = key; used[start+2] = true; size_++; return values[start+2]; } \
    if(!used[start+3]) { keys[start+3] = key; used[start+3] = true; size_++; return values[start+3]; }

#define CHECK_SET_4(start) \
    if(used[start] && keys[start] == key) { values[start] = value; return; } \
    if(used[start+1] && keys[start+1] == key) { values[start+1] = value; return; } \
    if(used[start+2] && keys[start+2] == key) { values[start+2] = value; return; } \
    if(used[start+3] && keys[start+3] == key) { values[start+3] = value; return; }

#define SET_EMPTY_4(start) \
    if(!used[start]) { keys[start] = key; values[start] = value; used[start] = true; size_++; return; } \
    if(!used[start+1]) { keys[start+1] = key; values[start+1] = value; used[start+1] = true; size_++; return; } \
    if(!used[start+2]) { keys[start+2] = key; values[start+2] = value; used[start+2] = true; size_++; return; } \
    if(!used[start+3]) { keys[start+3] = key; values[start+3] = value; used[start+3] = true; size_++; return; }

#define DEL_SLOT_4(start) \
    if(used[start] && keys[start] == key) { used[start] = false; size_--; } \
    if(used[start+1] && keys[start+1] == key) { used[start+1] = false; size_--; } \
    if(used[start+2] && keys[start+2] == key) { used[start+2] = false; size_--; } \
    if(used[start+3] && keys[start+3] == key) { used[start+3] = false; size_--; }

#define CONTAINS_SLOT_4(start) \
    ((used[start] && keys[start] == key) || \
     (used[start+1] && keys[start+1] == key) || \
     (used[start+2] && keys[start+2] == key) || \
     (used[start+3] && keys[start+3] == key))

namespace shedskin {

template<class T1, class T2>
class tuple2 {
public:
    T1 first;
    T2 second;
    tuple2(__ss_int size, T1 t1, T2 t2) : first(t1), second(t2) {}

    T1 __getfirst__() const { return first; }
    T2 __getsecond__() const { return second; }
};

template<class K, class V>
class dict {
private:
    static const __ss_int SIZE = 256;  // Increased size
    K keys[SIZE];
    V values[SIZE];
    bool used[SIZE];
    __ss_int size_;

    void add_item(const K& key, const V& value, __ss_int index) {
        if(index < SIZE) {
            keys[index] = key;
            values[index] = value;
            used[index] = true;
            size_++;
        }
    }

public:
    dict() : size_(0) {
        // Initialize all slots as unused
        for(__ss_int i = 0; i < SIZE; i += 4) {
            INIT_USED_4(i);
        }
    }
    
    dict(__ss_int count) : dict() {}  // Constructor with count only

    // Constructor for variable number of tuples
    template<typename... Args>
    dict(__ss_int count, Args*... tuples) : dict() {
        __ss_int index = 0;
        (add_tuple(tuples, index++), ...);
    }

private:
    void add_tuple(tuple2<K,V>* p, __ss_int index) {
        if(p && index < SIZE) {
            add_item(p->first, p->second, index);
        }
    }

public:
    V& __getitem__(const K& key) {
        for(__ss_int i = 0; i < SIZE; i += 4) {
            CHECK_SLOT_4(i);
        }
        for(__ss_int i = 0; i < SIZE; i += 4) {
            FIND_EMPTY_4(i);
        }
        return values[0];  // Fallback
    }

    void __setitem__(const K& key, const V& value) {
        for(__ss_int i = 0; i < SIZE; i += 4) {
            CHECK_SET_4(i);
        }
        for(__ss_int i = 0; i < SIZE; i += 4) {
            SET_EMPTY_4(i);
        }
    }

    void __delitem__(const K& key) {
        for(__ss_int i = 0; i < SIZE; i += 4) {
            DEL_SLOT_4(i);
        }
    }

    bool __contains__(const K& key) const {
        for(__ss_int i = 0; i < SIZE; i += 4) {
            if(CONTAINS_SLOT_4(i)) return true;
        }
        return false;
    }

    V pop(const K& key, const V& default_val) {
        for(__ss_int i = 0; i < SIZE; i++) {
            if(used[i] && keys[i] == key) {
                V val = values[i];
                used[i] = false;
                size_--;
                return val;
            }
        }
        return default_val;
    }

    __ss_int __len__() const {
        return size_;
    }
};

} // namespace shedskin
#endif