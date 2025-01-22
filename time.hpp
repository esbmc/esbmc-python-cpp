#ifndef __TIME_HPP
#define __TIME_HPP

#include "builtin.hpp"
#include <ctime>

#ifdef WIN32
    #include <windows.h>
    #include <time.h>
    #include <sys/timeb.h>
#else
    #include <sys/time.h>
    #include <time.h>  // for nanosleep
#endif

namespace __time__ {
    using namespace shedskin;
    
    extern str* name;
    extern class_* cl_struct_time;

    class struct_time : public pyobj {
    public:
        __ss_int tm_sec;
        __ss_int tm_hour;
        __ss_int tm_mday;
        __ss_int tm_isdst;
        __ss_int tm_year;
        __ss_int tm_mon;
        __ss_int tm_yday;
        __ss_int tm_wday;
        __ss_int tm_min;

        struct_time() { 
            this->__class__ = cl_struct_time; 
        }
    };

    // Sleep implementation using nanosleep
    inline void sleep(__ss_float seconds) {
        #ifdef WIN32
            Sleep(static_cast<DWORD>(seconds * 1000));
        #else
            struct timespec ts;
            ts.tv_sec = static_cast<time_t>(seconds);
            ts.tv_nsec = static_cast<long>((seconds - ts.tv_sec) * 1000000000L);
            nanosleep(&ts, NULL);
        #endif
    }

    // Rest of the implementation remains the same
    __ss_float mktime(struct_time *t);
    tuple2<str *, str *> *strptime(str *string, str *format);
    struct_time *localtime(__ss_float timer);
    struct_time *gmtime(__ss_float timer);
    str *strftime(str *format, struct_time *t);
    __ss_float time();

    inline str *asctime(struct_time *t) {
        return strftime(new str("%a %b %d %H:%M:%S %Y"), t);
    }

    inline str *ctime(__ss_float timer) {
        return asctime(localtime(timer));
    }

    void __init() {
        name = new str("time");
        cl_struct_time = new class_();
    }
}

#endif // __TIME_HPP