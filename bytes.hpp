#ifndef SS_BYTES_HPP
#define SS_BYTES_HPP

#include "builtin.hpp"
#include <vector>
#include <string>
#include <stdexcept>

namespace shedskin {

    class bytes : public pyobj {
    private:
        std::vector<unsigned char> data;

    public:
        // Default constructor
        bytes() {}
        bytes(const std::string& str) : data(str.begin(), str.end()) {}
        bytes(const unsigned char* arr, size_t len) : data(arr, arr + len) {}
        

        // Constructor from C-string
        bytes(const char* str) {
            while (*str) {
                data.push_back(static_cast<unsigned char>(*str));
                ++str;
            }
        }

        // Constructor from C-string with specified length
        bytes(const char* str, size_t len) {
            const unsigned char* start = reinterpret_cast<const unsigned char*>(str);
            data.clear();
            for (size_t i = 0; i < len; ++i) {
                data.push_back(start[i]);
            }
        }

        // Get the length of the data
        size_t __len__() const {
            return data.size();
        }

        size_t size() const {
            return data.size();
        }

        // Indexing with support for negative indices
        unsigned char __getitem__(int index) const {
            if (index < 0) {
                index += data.size();
            }
            if (index < 0 || index >= static_cast<int>(data.size())) {
                throw std::out_of_range("Index out of range");
            }
            return data[index];
        }

        // Append a byte to the data
        void append(unsigned char value) {
            data.push_back(value);
        }

        // Convert to string representation
        std::string vector_to_string(const std::vector<unsigned char>& vec) {
            std::string result;
            for (auto c : vec) {
                result += static_cast<char>(c);  // Utiliser l'opérateur d'ajout de std::string
            }
            return result;
        }

        // Check equality with another bytes object
        bool equals(const bytes* other) const {
            if (!other) return false;
            return compare_vectors(this->data, other->data);
        }

        template <typename T>
        static bool compare_vectors(const std::vector<T>& a, const std::vector<T>& b) {
            if (a.size() != b.size()) return false;
            for (size_t i = 0; i < a.size(); ++i) {
                if (a[i] != b[i]) return false;
            }
            return true;
        }

        // Debug method to print the data
        void print() const {
            for (auto& byte : data) {
                std::cout << static_cast<int>(byte) << " ";
            }
            std::cout << std::endl;
        }
        
    };

    __ss_int len(shedskin::bytes* b) {
        return b ? static_cast<__ss_int>(b->size()) : 0;
    }

} // namespace shedskin

#endif // SS_BYTES_HPP

