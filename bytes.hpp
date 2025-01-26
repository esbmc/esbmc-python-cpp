#ifndef SS_BYTES_HPP
#define SS_BYTES_HPP
#include "builtin.hpp"
#include <string>
#include <stdexcept>

namespace shedskin {
    class bytes : public pyobj {
    private:
        unsigned char* data;
        size_t capacity;
        size_t length;

    public:
        bytes() : data(nullptr), capacity(0), length(0) {}
        
        bytes(const std::string& str) {
            length = str.length();
            capacity = length;
            data = new unsigned char[capacity];
            for (size_t i = 0; i < length; ++i) {
                data[i] = static_cast<unsigned char>(str.at(i));
            }
        }

        bytes(const unsigned char* arr, size_t len) {
            length = len;
            capacity = len;
            data = new unsigned char[capacity];
            for (size_t i = 0; i < len; ++i) {
                data[i] = arr[i];
            }
        }

        bytes(const char* str) {
            length = 0;
            while (str[length]) ++length;
            capacity = length;
            data = new unsigned char[capacity];
            for (size_t i = 0; i < length; ++i) {
                data[i] = static_cast<unsigned char>(str[i]);
            }
        }

        bytes(const char* str, size_t len) {
            length = len;
            capacity = len;
            data = new unsigned char[capacity];
            const unsigned char* start = reinterpret_cast<const unsigned char*>(str);
            for (size_t i = 0; i < len; ++i) {
                data[i] = start[i];
            }
        }

        ~bytes() {
            delete[] data;
        }

        // Copy constructor
        bytes(const bytes& other) {
            length = other.length;
            capacity = other.capacity;
            data = new unsigned char[capacity];
            for (size_t i = 0; i < length; ++i) {
                data[i] = other.data[i];
            }
        }

        // Assignment operator
        bytes& operator=(const bytes& other) {
            if (this != &other) {
                delete[] data;
                length = other.length;
                capacity = other.capacity;
                data = new unsigned char[capacity];
                for (size_t i = 0; i < length; ++i) {
                    data[i] = other.data[i];
                }
            }
            return *this;
        }

        size_t len() const {
            return length;
        }

        size_t size() const {
            return length;
        }

        unsigned char getitem(int index) const {
            if (index < 0) {
                index += length;
            }
            if (index < 0 || index >= static_cast<int>(length)) {
                throw std::out_of_range("Index out of range");
            }
            return data[index];
        }

        void append(unsigned char value) {
            if (length == capacity) {
                size_t new_capacity = (capacity == 0) ? 1 : capacity * 2;
                unsigned char* new_data = new unsigned char[new_capacity];
                for (size_t i = 0; i < length; ++i) {
                    new_data[i] = data[i];
                }
                delete[] data;
                data = new_data;
                capacity = new_capacity;
            }
            data[length++] = value;
        }

        std::string to_string() const {
            return std::string(reinterpret_cast<const char*>(data), length);
        }

        bool equals(const bytes* other) const {
            if (!other) return false;
            if (length != other->length) return false;
            for (size_t i = 0; i < length; ++i) {
                if (data[i] != other->data[i]) return false;
            }
            return true;
        }

        void print() const {
            for (size_t i = 0; i < length; ++i) {
                std::cout << static_cast<int>(data[i]) << " ";
            }
            std::cout << std::endl;
        }
    };

    __ss_int len(shedskin::bytes* b) {
        return b ? static_cast<__ss_int>(b->size()) : 0;
    }
} // namespace shedskin
#endif // SS_BYTES_HPP
