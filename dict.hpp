#ifndef __DICT_HPP
#define __DICT_HPP

// Helper macros for generating repeated patterns
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
    static const __ss_int SIZE = 32;  // Increased size, multiple of 4
    K keys[SIZE];
    V values[SIZE];
    bool used[SIZE];
    __ss_int size_;

public:
    dict() : size_(0) {
        // Initialize in blocks of 4
        INIT_USED_4(0)  INIT_USED_4(4)  INIT_USED_4(8)  INIT_USED_4(12)
        INIT_USED_4(16) INIT_USED_4(20) INIT_USED_4(24) INIT_USED_4(28)
    }
    
    dict(__ss_int count, tuple2<K,V>* p1) : dict() {
        if(p1) { 
            keys[0] = p1->first; 
            values[0] = p1->second;
            used[0] = true;
            size_ = 1;
        }
    }
    
    dict(__ss_int count, tuple2<K,V>* p1, tuple2<K,V>* p2) : dict(count, p1) {
        if(p2 && size_ < SIZE) {
            keys[1] = p2->first;
            values[1] = p2->second;
            used[1] = true;
            size_++;
        }
    }
    
    dict(__ss_int count, tuple2<K,V>* p1, tuple2<K,V>* p2, tuple2<K,V>* p3) 
        : dict(count, p1, p2) {
        if(p3 && size_ < SIZE) {
            keys[2] = p3->first;
            values[2] = p3->second;
            used[2] = true;
            size_++;
        }
    }

    V& __getitem__(const K& key) {
        // Check existing slots in blocks of 4
        CHECK_SLOT_4(0)  CHECK_SLOT_4(4)  CHECK_SLOT_4(8)  CHECK_SLOT_4(12)
        CHECK_SLOT_4(16) CHECK_SLOT_4(20) CHECK_SLOT_4(24) CHECK_SLOT_4(28)
        
        // Find empty slots in blocks of 4
        FIND_EMPTY_4(0)  FIND_EMPTY_4(4)  FIND_EMPTY_4(8)  FIND_EMPTY_4(12)
        FIND_EMPTY_4(16) FIND_EMPTY_4(20) FIND_EMPTY_4(24) FIND_EMPTY_4(28)
        
        return values[0];
    }

    void __setitem__(const K& key, const V& value) {
        // Check existing slots in blocks of 4
        CHECK_SET_4(0)  CHECK_SET_4(4)  CHECK_SET_4(8)  CHECK_SET_4(12)
        CHECK_SET_4(16) CHECK_SET_4(20) CHECK_SET_4(24) CHECK_SET_4(28)
        
        // Find empty slots in blocks of 4
        SET_EMPTY_4(0)  SET_EMPTY_4(4)  SET_EMPTY_4(8)  SET_EMPTY_4(12)
        SET_EMPTY_4(16) SET_EMPTY_4(20) SET_EMPTY_4(24) SET_EMPTY_4(28)
    }

    void __delitem__(const K& key) {
        DEL_SLOT_4(0)  DEL_SLOT_4(4)  DEL_SLOT_4(8)  DEL_SLOT_4(12)
        DEL_SLOT_4(16) DEL_SLOT_4(20) DEL_SLOT_4(24) DEL_SLOT_4(28)
    }

    bool __contains__(const K& key) const {
        return CONTAINS_SLOT_4(0) || CONTAINS_SLOT_4(4) || CONTAINS_SLOT_4(8) || 
               CONTAINS_SLOT_4(12) || CONTAINS_SLOT_4(16) || CONTAINS_SLOT_4(20) || 
               CONTAINS_SLOT_4(24) || CONTAINS_SLOT_4(28);
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