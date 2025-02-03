#ifndef SHEDSKIN_TIME_HPP
#define SHEDSKIN_TIME_HPP

// Forward declare the shedskin namespace and required types
namespace shedskin {
    typedef long long __ss_int;
    typedef double __ss_float;
    class str;
    class pyobj;
    class class_;
    template<class T1, class T2> class tuple2;
}

#ifdef _WIN32
    #include <windows.h>
    #include <time.h>
    #include <sys/timeb.h>
#else
    #include <sys/time.h>
#endif

// Now define the shedskin_time namespace
namespace shedskin_time {

    #ifdef _WIN32
    struct __ss_timezone {
        int tz_minuteswest;
        int tz_dsttime;
    };
    
    inline shedskin::__ss_int gettimeofday(struct timeval* tv, struct __ss_timezone* tz) {
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

    extern shedskin::class_* cl_struct_time;

    class struct_time : public shedskin::pyobj {
    public:
        shedskin::__ss_int tm_sec;    
        shedskin::__ss_int tm_min;    
        shedskin::__ss_int tm_hour;   
        shedskin::__ss_int tm_mday;   
        shedskin::__ss_int tm_mon;    
        shedskin::__ss_int tm_year;   
        shedskin::__ss_int tm_wday;   
        shedskin::__ss_int tm_yday;   
        shedskin::__ss_int tm_isdst;  

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

        struct_time(shedskin::tuple2<shedskin::__ss_int, shedskin::__ss_int>* tuple);
        
        shedskin::__ss_int getitem(shedskin::__ss_int n) const {
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

        shedskin::str* repr();

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
    extern shedskin::__ss_int timezone;
    extern shedskin::tuple2<shedskin::str*, shedskin::str*>* tzname;
    extern shedskin::str* name;

    // Core time functions
    shedskin::__ss_float time();
    void sleep(shedskin::__ss_float seconds);
    shedskin::__ss_float mktime(struct_time* tuple);
    shedskin::__ss_float mktime(shedskin::tuple2<shedskin::__ss_int, shedskin::__ss_int>* tuple);
    struct_time* localtime();
    struct_time* localtime(const shedskin::__ss_float timep);
    struct_time* gmtime();
    struct_time* gmtime(const shedskin::__ss_float seconds);
    shedskin::str* asctime();
    shedskin::str* asctime(struct_time* tuple);
    shedskin::str* ctime();
    shedskin::str* ctime(const shedskin::__ss_float seconds);
    shedskin::str* strftime(shedskin::str* format, struct_time* tuple);
    shedskin::str* strftime(shedskin::str* format);
    shedskin::str* strftime(shedskin::str* format, shedskin::tuple2<shedskin::__ss_int, shedskin::__ss_int>* tuple);
    struct_time* strptime(shedskin::str* string, shedskin::str* format);

    #ifdef _WIN32
    extern "C" char* strptime(const char* s, const char* f, struct tm* tm);
    #endif

    void __init();

} // namespace shedskin_time

#endif