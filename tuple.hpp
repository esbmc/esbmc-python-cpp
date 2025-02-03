#ifndef SS_TUPLE_HPP
#define SS_TUPLE_HPP

#include "list.hpp"
#include "dict.hpp"  // Include dict.hpp for tuple2 definition

namespace shedskin {

extern __ss_int __result;

#define FOR_IN(e, iter, iter_name, counter, loop_name) \
    if (0) goto __after_yield_##counter; \
    { \
        bool __yielded_##counter = false; \
        __after_yield_##counter: \
        for(;!__yielded_##counter;) { \
            __yielded_##counter = true; \
            goto __body_##counter; \
        } \
        __body_##counter:;

#define END_FOR \
    }

#define FAST_FOR(e, start, stop, step, counter1, counter2) \
    for(__ss_int e = start; e < stop; e += step)

template<typename T>
T __zero() { 
    return T();
}

// Keep tuple3 since it's not in dict.hpp
template<typename T1, typename T2, typename T3>
class tuple3 {
public:
    T1 first;
    T2 second;
    T3 third;
    tuple3(__ss_int size, T1 t1, T2 t2, T3 t3) : first(t1), second(t2), third(t3) {}

    T1 __getfirst__() const { return first; }
    T2 __getsecond__() const { return second; }
    T3 __getthird__() const { return third; }
};

// Helper functions for tuple creation
template<typename T1, typename T2>
tuple2<T1,T2>* __tuple2(T1 a, T2 b) {
    return new tuple2<T1,T2>(2, a, b);
}

template<typename T1, typename T2, typename T3>
tuple3<T1,T2,T3>* __tuple3(T1 a, T2 b, T3 c) {
    return new tuple3<T1,T2,T3>(3, a, b, c);
}

} // namespace shedskin

#endif