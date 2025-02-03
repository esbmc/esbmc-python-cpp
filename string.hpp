#ifndef SS_STRING_HPP
#define SS_STRING_HPP

#include "builtin.hpp"
#include <cstring>
#include <cctype>
#include <cstdarg>
#include <stdexcept>

namespace shedskin {

// Note: str class is already defined in builtin.hpp
// Implement methods for the existing str class

str* str::strip() const {
    if (!data) return new str();
    const char* start = data;
    const char* end = data + strlen(data) - 1;
    
    while (*start && isspace(*start)) start++;
    while (end > start && isspace(*end)) end--;
    
    size_t len = end - start + 1;
    char* result_str = new char[len + 1];
    strncpy(result_str, start, len);
    result_str[len] = '\0';
    
    str* result = new str(result_str);
    delete[] result_str;
    return result;
}

str* str::upper() const {
    if (!data) return new str();
    char* result_str = strdup(data);
    char* p = result_str;
    while (*p) {
        *p = toupper(*p);
        p++;
    }
    str* result = new str(result_str);
    free(result_str);
    return result;
}

str* str::lower() const {
    if (!data) return new str();
    char* result_str = strdup(data);
    char* p = result_str;
    while (*p) {
        *p = tolower(*p);
        p++;
    }
    str* result = new str(result_str);
    free(result_str);
    return result;
}

str* str::replace(const str* old_str, const str* new_str) const {
    if (!data || !old_str || !old_str->data || !new_str || !new_str->data) 
        return new str(data);
    
    const char* pos = data;
    size_t count = 0;
    size_t old_len = strlen(old_str->data);
    
    while ((pos = strstr(pos, old_str->data))) {
        count++;
        pos += old_len;
    }
    
    if (count == 0) return new str(data);
    
    size_t new_len = strlen(new_str->data);
    size_t final_size = strlen(data) + count * (new_len - old_len) + 1;
    
    char* result_str = new char[final_size];
    const char* current = data;
    char* dest = result_str;
    
    while ((pos = strstr(current, old_str->data))) {
        size_t keep_len = pos - current;
        memcpy(dest, current, keep_len);
        dest += keep_len;
        memcpy(dest, new_str->data, new_len);
        dest += new_len;
        current = pos + old_len;
    }
    
    strcpy(dest, current);
    str* result = new str(result_str);
    delete[] result_str;
    return result;
}

str* str::format() const {
    return new str(data);
}

str* str::__add__(const str* other) const {
    if (!this->data && !other->data) return new str();
    if (!this->data) return new str(other->data);
    if (!other->data) return new str(this->data);
    
    size_t new_len = strlen(this->data) + strlen(other->data) + 1;
    char* result_str = new char[new_len];
    strcpy(result_str, this->data);
    strcat(result_str, other->data);
    str* result = new str(result_str);
    delete[] result_str;
    return result;
}

str* str::__getitem__(__ss_int i) const {
    if (!data) {
        throw std::out_of_range("Index out of range: string data is null");
    }
    if (i < 0) i += __len__();
    if (i < 0 || i >= __len__()) {
        throw std::out_of_range("Index out of range: invalid index");
    }
    
    // Create a single character string
    char c[2] = {data[i], '\0'};
    return new str(c);
}

// String conversion functions
str* __str(const char* s) {
    return new str(s);
}

str* __str(const str* s) {
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

str* __str(bool b) {
    return new str(b ? "True" : "False");
}

str* __add_strs(int count, ...) {
    va_list args;
    va_start(args, count);
    
    size_t total_len = 1;
    va_list args_copy;
    va_copy(args_copy, args);
    for (int i = 0; i < count; i++) {
        const str* s = va_arg(args_copy, const str*);
        if (s && s->c_str()) {
            total_len += strlen(s->c_str());
        }
    }
    va_end(args_copy);
    
    char* result_str = new char[total_len];
    result_str[0] = '\0';
    
    char* dest = result_str;
    for (int i = 0; i < count; i++) {
        const str* s = va_arg(args, const str*);
        if (s && s->c_str()) {
            strcpy(dest, s->c_str());
            dest += strlen(s->c_str());
        }
    }
    va_end(args);
    
    str* result = new str(result_str);
    delete[] result_str;
    return result;
}

str* __mod6(const str* format_str, int count, ...) {
    if (!format_str || !format_str->c_str()) return new str();
    
    va_list args;
    va_start(args, count);
    
    const char* fmt = format_str->c_str();
    size_t total_len = strlen(fmt) + 1;
    
    va_list args_copy;
    va_copy(args_copy, args);
    const char* p = fmt;
    while ((p = strstr(p, "%s"))) {
        const str* arg = va_arg(args_copy, const str*);
        if (arg && arg->c_str()) {
            total_len += strlen(arg->c_str()) - 2;
        }
        p += 2;
    }
    va_end(args_copy);
    
    char* result_str = new char[total_len];
    char* dest = result_str;
    p = fmt;
    const char* last = p;
    
    while ((p = strstr(p, "%s"))) {
        size_t chunk = p - last;
        memcpy(dest, last, chunk);
        dest += chunk;
        
        const str* arg = va_arg(args, const str*);
        if (arg && arg->c_str()) {
            strcpy(dest, arg->c_str());
            dest += strlen(arg->c_str());
        }
        p += 2;
        last = p;
    }
    strcpy(dest, last);
    va_end(args);
    
    str* result = new str(result_str);
    delete[] result_str;
    return result;
}

} // namespace shedskin

namespace __shedskin__ = shedskin;

#endif