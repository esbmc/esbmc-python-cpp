#ifndef SS_TUPLE_HPP
#define SS_TUPLE_HPP

namespace shedskin {
template<class A, class B> 
class tuple2 : public pyobj {
public:
    A first;
    B second;
    int size;
    tuple2() : size(0), first(), second() {
        __class__ = NULL;  // Fixed "class" to "__class__"
    }
    tuple2(int n, A a, B b) : size(n), first(a), second(b) {
        __class__ = NULL;  // Fixed "class" to "__class__"
    }
    A __getfirst__() {   // Changed from getfirst
        return first; 
    }
    B __getsecond__() {  // Changed from getsecond
        return second; 
    }
    __ss_int __len__() { // Changed from len
        return 2; 
    }
    __ss_bool __eq__(pyobj* p) {  // Changed from eq
        tuple2<A,B>* b = (tuple2<A,B>*)p;
        return __eq(first, b->first) && __eq(second, b->second);  // Fixed "__eq" function call
    }
    str* __repr__() {  // Changed from repr
        // Simplified repr - only used for debug
        return nullptr;
    }
};
} // namespace shedskin

#endif