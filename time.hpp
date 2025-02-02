#ifndef SHEDSKIN_TIME_HPP
#define SHEDSKIN_TIME_HPP

#include "builtin.hpp"

#ifdef _WIN32
    #include <windows.h>
    #include <time.h>
    #include <sys/timeb.h>
#else
    #include <sys/time.h>
#endif

// Avoid including any iostream headers
namespace shedskin_time {

using namespace shedskin;

#ifdef _WIN32
struct __ss_timezone {
    int tz_minuteswest;
    int tz_dsttime;
};

inline __ss_int gettimeofday(struct timeval* tv, struct __ss_timezone* tz) {
    if (tv) {
        FILETIME ft;
        GetSystemTimeAsFileTime(&ft);
        unsigned __int64 tmp = 0;
        tmp |= ft.dwHighDateTime;
        tmp <<= 32;
        tmp |= ft.dwLowDateTime;
        tmp /= 10;
        tmp -= 11644473600000000ULL;
        tv->tv_sec = (long)(tmp / 1000000UL);
        tv->tv_usec = (long)(tmp % 1000000UL);
    }
    if (tz) {
        TIME_ZONE_INFORMATION tzi;
        GetTimeZoneInformation(&tzi);
        tz->tz_minuteswest = tzi.Bias;
        tz->tz_dsttime = (tzi.StandardDate.wMonth != 0);
    }
    return 0;
}
#endif

// Forward declare
extern class_* cl_struct_time;

class struct_time : public pyobj {
public:
    __ss_int tm_sec;    
    __ss_int tm_min;    
    __ss_int tm_hour;   
    __ss_int tm_mday;   
    __ss_int tm_mon;    
    __ss_int tm_year;   
    __ss_int tm_wday;   
    __ss_int tm_yday;   
    __ss_int tm_isdst;  

    struct_time() {
        this->__class__ = cl_struct_time;
    }

    struct_time(const struct tm& t) :
        tm_sec(t.tm_sec),
        tm_min(t.tm_min),
        tm_hour(t.tm_hour),
        tm_mday(t.tm_mday),
        tm_mon(t.tm_mon),
        tm_year(t.tm_year),
        tm_wday(t.tm_wday),
        tm_yday(t.tm_yday),
        tm_isdst(t.tm_isdst) {
        this->__class__ = cl_struct_time;
    }

    struct_time(tuple2<__ss_int, __ss_int>* tuple);
    
    __ss_int getitem(__ss_int n) const {
        switch(n) {
            case 0: return tm_year;
            case 1: return tm_mon;
            case 2: return tm_mday;
            case 3: return tm_hour;
            case 4: return tm_min;
            case 5: return tm_sec;
            case 6: return tm_wday;
            case 7: return tm_yday;
            case 8: return tm_isdst;
            default: return 0;
        }
    }

    str* repr();

    operator struct tm() const {
        struct tm result = {};
        result.tm_sec = tm_sec;
        result.tm_min = tm_min;
        result.tm_hour = tm_hour;
        result.tm_mday = tm_mday;
        result.tm_mon = tm_mon;
        result.tm_year = tm_year;
        result.tm_wday = tm_wday;
        result.tm_yday = tm_yday;
        result.tm_isdst = tm_isdst;
        return result;
    }
};

// Constants
extern __ss_int timezone;
extern tuple2<str*, str*>* tzname;
extern str* name;

// Core time functions
__ss_float time();
void sleep(__ss_float seconds);
__ss_float mktime(struct_time* tuple);
__ss_float mktime(tuple2<__ss_int, __ss_int>* tuple);
struct_time* localtime();
struct_time* localtime(const __ss_float timep);
struct_time* gmtime();
struct_time* gmtime(const __ss_float seconds);
str* asctime();
str* asctime(struct_time* tuple);
str* ctime();
str* ctime(const __ss_float seconds);
str* strftime(str* format, struct_time* tuple);
str* strftime(str* format);
str* strftime(str* format, tuple2<__ss_int, __ss_int>* tuple);
struct_time* strptime(str* string, str* format);

#ifdef _WIN32
extern "C" char* strptime(const char* s, const char* f, struct tm* tm);
#endif

void __init();

} // namespace shedskin_time

#endif // SHEDSKIN_TIME_HPP