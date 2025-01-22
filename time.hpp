// time.hpp
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
#endif

namespace __time__ {
    using namespace __shedskin__;

    extern str* __name__;
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

        struct_time() { this->__class__ = cl_struct_time; }
    };

    void __init() {
        __name__ = new str("time");
        cl_struct_time = new class_();
    }
}

#endif // __TIME_HPP
