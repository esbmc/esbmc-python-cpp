#ifndef __STR_HPP
#define __STR_HPP

#include "list.hpp"

namespace shedskin {

class str : public pyobj {
private:
    char* data;
    __ss_int length;

public:
    str() : data(nullptr), length(0) {}
    
    str(const char* s) {
        if(s) {
            length = strlen(s);
            data = new char[length + 1];
            strcpy(data, s);
        } else {
            data = nullptr;
            length = 0;
        }
    }
    
    str(const str& other) {
        if(other.data) {
            length = other.length;
            data = new char[length + 1];
            strcpy(data, other.data);
        } else {
            data = nullptr;
            length = 0;
        }
    }
    
    ~str() {
        if(data) delete[] data;
    }
    
    __ss_int __len__() const {
        return length;
    }
    
    str __getitem__(__ss_int index) const {
        if(index < 0 || index >= length) return str();
        char ch[2] = {data[index], '\0'};
        return str(ch);
    }
    
    bool operator==(const str& other) const {
        if(length != other.length) return false;
        return strcmp(data, other.data) == 0;
    }
    
    operator const char*() const {
        return data;
    }

    // Check prefix
    bool startswith(const str& prefix, __ss_int start = 0) const {
        if (!prefix.data) return false;
        if (start < 0) start = 0;
        if (start + prefix.length > length) return false;
        return memcmp(data + start, prefix.data, prefix.length) == 0;
    }

    // Check suffix
    bool endswith(const str& suffix, __ss_int start = 0) const {
        if (!suffix.data) return false;
        if (start < 0) start = 0;
        __ss_int effective_len = length - start;
        if (suffix.length > effective_len) return false;
        return memcmp(data + (length - suffix.length), suffix.data, suffix.length) == 0;
    }

    // Find substring from start, return -1 if not found
    __ss_int find(const str& sub, __ss_int start = 0) const {
        if (!sub.data || sub.length == 0) return start < length ? start : length;
        if (start < 0) start = 0;
        for (__ss_int i = start; i + sub.length <= length; i++) {
            if (memcmp(data + i, sub.data, sub.length) == 0) {
                return i;
            }
        }
        return -1;
    }

    // Reverse find substring, return -1 if not found
    __ss_int rfind(const str& sub, __ss_int start = 0) const {
        if (!sub.data || sub.length == 0) return length;
        if (start < 0) start = 0;
        __ss_int begin = start;
        if (begin > length) begin = length;
        for (__ss_int i = length - sub.length; i >= begin; i--) {
            if (memcmp(data + i, sub.data, sub.length) == 0) {
                return i;
            }
            if (i == 0) break;
        }
        return -1;
    }
};

} // namespace shedskin

#endif
