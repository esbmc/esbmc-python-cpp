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
};

} // namespace shedskin

#endif
