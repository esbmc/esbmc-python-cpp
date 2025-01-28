#ifndef SS_STRING_HPP
#define SS_STRING_HPP

#include "builtin.hpp"
#include <cstring>
#include <cctype>
#include <cstdarg>

namespace shedskin {

// String manipulation methods implementation
str* str::strip() const {
    if (!data) return new str();
    const char* start = data;
    const char* end = data + strlen(data) - 1;
    
    while (*start && isspace(*start)) start++;
    while (end > start && isspace(*end)) end--;
    
    size_t len = end - start + 1;
    char* newStr = new char[len + 1];
    strncpy(newStr, start, len);
    newStr[len] = '\0';
    
    str* result = new str(newStr);
    delete[] newStr;
    return result;
}

str* str::upper() const {
    if (!data) return new str();
    char* newStr = strdup(data);
    char* p = newStr;
    while (*p) {
        *p = toupper(*p);
        p++;
    }
    str* result = new str(newStr);
    free(newStr);
    return result;
}

str* str::lower() const {
    if (!data) return new str();
    char* newStr = strdup(data);
    char* p = newStr;
    while (*p) {
        *p = tolower(*p);
        p++;
    }
    str* result = new str(newStr);
    free(newStr);
    return result;
}

str* str::replace(const str* old_str, const str* new_str) const {
    if (!data || !old_str || !old_str->data || !new_str || !new_str->data) 
        return new str(data);
    
    // Calculate required buffer size
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
    
    char* result = new char[final_size];
    const char* current = data;
    char* dest = result;
    
    while ((pos = strstr(current, old_str->data))) {
        size_t keep_len = pos - current;
        memcpy(dest, current, keep_len);
        dest += keep_len;
        memcpy(dest, new_str->data, new_len);
        dest += new_len;
        current = pos + old_len;
    }
    
    strcpy(dest, current);
    str* str_result = new str(result);
    delete[] result;
    return str_result;
}

str* str::format() const {
    return new str(data);
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

// String concatenation
str* __add_strs(int count, ...) {
    va_list args;
    va_start(args, count);
    
    // Calculate total length needed
    size_t total_len = 1;  // for null terminator
    va_list args_copy;
    va_copy(args_copy, args);
    for (int i = 0; i < count; i++) {
        const str* s = va_arg(args_copy, const str*);
        if (s && s->data) {
            total_len += strlen(s->data);
        }
    }
    va_end(args_copy);
    
    // Concatenate strings
    char* result = new char[total_len];
    result[0] = '\0';
    
    char* dest = result;
    for (int i = 0; i < count; i++) {
        const str* s = va_arg(args, const str*);
        if (s && s->data) {
            strcpy(dest, s->data);
            dest += strlen(s->data);
        }
    }
    va_end(args);
    
    str* str_result = new str(result);
    delete[] result;
    return str_result;
}

// String formatting
str* __mod6(const str* format_str, int count, ...) {
    if (!format_str || !format_str->data) return new str();
    
    va_list args;
    va_start(args, count);
    
    const char* fmt = format_str->data;
    size_t total_len = strlen(fmt) + 1;
    
    // First pass: calculate required size
    va_list args_copy;
    va_copy(args_copy, args);
    const char* p = fmt;
    while ((p = strstr(p, "%s"))) {
        const str* arg = va_arg(args_copy, const str*);
        if (arg && arg->data) {
            total_len += strlen(arg->data) - 2;  // -2 for "%s"
        }
        p += 2;
    }
    va_end(args_copy);
    
    // Second pass: format string
    char* result = new char[total_len];
    char* dest = result;
    p = fmt;
    const char* last = p;
    
    while ((p = strstr(p, "%s"))) {
        size_t chunk = p - last;
        memcpy(dest, last, chunk);
        dest += chunk;
        
        const str* arg = va_arg(args, const str*);
        if (arg && arg->data) {
            strcpy(dest, arg->data);
            dest += strlen(arg->data);
        }
        p += 2;
        last = p;
    }
    strcpy(dest, last);
    va_end(args);
    
    str* str_result = new str(result);
    delete[] result;
    return str_result;
}

str* str::__add__(const str* other) const {
    if (!this->data || !other->data) {
        return new str();
    }
    size_t new_len = strlen(this->data) + strlen(other->data) + 1;
    char* result = new char[new_len];
    strcpy(result, this->data);
    strcat(result, other->data);
    str* concatenated = new str(result);
    delete[] result;
    return concatenated;
}

str* str::__getitem__(__ss_int i) const {
    if (!data) {
        throw std::out_of_range("Index out of range: string data is null");
    }
    if (i < 0) i += __len__();  // Managing negative indices
    if (i < 0 || i >= __len__()) {
        throw std::out_of_range("Index out of range: invalid index");
    }
    unsigned char char_index = static_cast<unsigned char>(data[i]);  // Retrieve character
    if (!__char_cache[char_index]) {
        // If the cache is not initialized for this character, initialize it.
        char c[2] = {data[i], '\0'};  // Convert character to string
        __char_cache[char_index] = new str(c);
    }
    return __char_cache[char_index];  // Return character from cache
}

} // namespace shedskin

namespace __shedskin__ = shedskin;

#endif