#ifndef SS_STRING_HPP
#define SS_STRING_HPP

#include "builtin.hpp"
#include <cstring>
#include <cctype>
#include <cstdarg>

namespace shedskin {

str* str::strip() const {
    if (!data) return new str();
    const char* start = data;
    const char* end = data + strlen(data) - 1;
    
    while (start <= end && isspace(*start)) start++;
    while (end > start && isspace(*end)) end--;
    
    size_t len = end - start + 1;
    str* result = new str();
    char* temp = new char[len + 1];
    strncpy(temp, start, len);
    temp[len] = '\0';
    result->data = temp;
    return result;
}

str* str::upper() const {
    if (!data) return new str();
    size_t len = strlen(data);
    str* result = new str();
    char* temp = new char[len + 1];
    for (size_t i = 0; i < len; i++) {
        temp[i] = toupper(data[i]);
    }
    temp[len] = '\0';
    result->data = temp;
    return result;
}

str* str::lower() const {
    if (!data) return new str();
    size_t len = strlen(data);
    str* result = new str();
    char* temp = new char[len + 1];
    for (size_t i = 0; i < len; i++) {
        temp[i] = tolower(data[i]);
    }
    temp[len] = '\0';
    result->data = temp;
    return result;
}

str* str::replace(const str* old_str, const str* new_str) const {
    if (!data || !old_str || !old_str->data || !new_str || !new_str->data) 
        return new str(data);
    
    const size_t old_len = strlen(old_str->data);
    const size_t new_len = strlen(new_str->data);
    const size_t data_len = strlen(data);
    
    size_t count = 0;
    const char* pos = data;
    while ((pos = strstr(pos, old_str->data))) {
        count++;
        pos += old_len;
    }
    
    if (!count) return new str(data);
    
    const size_t final_size = data_len + count * (new_len - old_len);
    str* result = new str();
    char* temp = new char[final_size + 1];
    
    const char* current = data;
    char* dest = temp;
    
    while ((pos = strstr(current, old_str->data))) {
        const size_t chunk_size = pos - current;
        strncpy(dest, current, chunk_size);
        dest += chunk_size;
        strncpy(dest, new_str->data, new_len);
        dest += new_len;
        current = pos + old_len;
    }
    
    strcpy(dest, current);
    result->data = temp;
    return result;
}

str* str::format() const {
    return new str(data);
}

inline str* __str(const char* s) {
    return new str(s);
}

inline str* __str(const str* s) {
    return new str(s->c_str());
}

str* __str(int n) {
    char buf[32];
    snprintf(buf, sizeof(buf), "%d", n);
    return new str(buf);
}

str* __str(double n) {
    char buf[32];
    snprintf(buf, sizeof(buf), "%g", n);
    return new str(buf);
}

inline str* __str(bool b) {
    return new str(b ? "True" : "False");
}

str* __add_strs(int count, ...) {
    va_list args;
    va_start(args, count);
    
    size_t total_len = 0;
    va_list args_copy;
    va_copy(args_copy, args);
    
    for (int i = 0; i < count; i++) {
        const str* s = va_arg(args_copy, const str*);
        if (s && s->data) total_len += strlen(s->data);
    }
    va_end(args_copy);
    
    str* result = new str();
    char* temp = new char[total_len + 1];
    char* dest = temp;
    
    for (int i = 0; i < count; i++) {
        const str* s = va_arg(args, const str*);
        if (s && s->data) {
            const size_t len = strlen(s->data);
            strncpy(dest, s->data, len);
            dest += len;
        }
    }
    *dest = '\0';
    result->data = temp;
    va_end(args);
    return result;
}

str* __mod6(const str* format_str, int count, ...) {
    if (!format_str || !format_str->data) return new str();
    
    va_list args;
    va_start(args, count);
    
    const char* fmt = format_str->data;
    size_t total_len = 0;
    
    va_list args_copy;
    va_copy(args_copy, args);
    const char* p = fmt;
    const char* last = p;
    
    while ((p = strstr(p, "%s"))) {
        total_len += p - last;
        const str* arg = va_arg(args_copy, const str*);
        if (arg && arg->data) total_len += strlen(arg->data);
        p += 2;
        last = p;
    }
    total_len += strlen(last);
    va_end(args_copy);
    
    str* result = new str();
    char* temp = new char[total_len + 1];
    char* dest = temp;
    
    p = fmt;
    last = p;
    while ((p = strstr(p, "%s"))) {
        const size_t chunk = p - last;
        strncpy(dest, last, chunk);
        dest += chunk;
        
        const str* arg = va_arg(args, const str*);
        if (arg && arg->data) {
            const size_t len = strlen(arg->data);
            strncpy(dest, arg->data, len);
            dest += len;
        }
        p += 2;
        last = p;
    }
    strcpy(dest, last);
    result->data = temp;
    va_end(args);
    return result;
}

} // namespace shedskin
namespace __shedskin__ = shedskin;
#endif