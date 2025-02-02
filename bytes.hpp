#ifndef SHEDSKIN_BYTES_HPP
#define SHEDSKIN_BYTES_HPP

#include <string>
#include <cstring>

namespace shedskin {

// Forward declarations
template<class T> class list;
template<class T, class U> class tuple2;
class str;
class pyobj;
template<class T> class pyiter;

// Base template class for sequences
template<class T>
class pyseq {
public:
    virtual ~pyseq() {}
    virtual T __getitem__(__ss_int i) = 0;
    virtual __ss_int __len__() = 0;
};

// Type definitions (without redefining True/False)
typedef int __ss_int;
typedef bool __ss_bool;
typedef std::__1::string __GC_STRING;

class bytes : public pyseq<__ss_int> {
protected:
public:
    __GC_STRING unit;
    long hash;
    int frozen;

    // Constructors
    bytes(int frozen=1) {}
    bytes(const char *s) {}
    bytes(bytes *b, int frozen=1) {}
    bytes(__GC_STRING s, int frozen=1) {}
    bytes(const char *s, int size, int frozen=1) {}

    // Basic operations
    inline __ss_int __getitem__(__ss_int i) override { return 0; }
    inline __ss_int __getfast__(__ss_int i) { return 0; }
    template<class U> bytes *join(U *) { return nullptr; }
    inline __ss_int __len__() override { return 0; }
    bytes *__slice__(__ss_int x, __ss_int l, __ss_int u, __ss_int s) { return nullptr; }

    // String manipulation
    bytes *rstrip(bytes *chars=0) { return nullptr; }
    bytes *strip(bytes *chars=0) { return nullptr; }
    bytes *lstrip(bytes *chars=0) { return nullptr; }
    
    // Split operations
    list<bytes *> *split(bytes *sep=0, __ss_int maxsplit=-1) { return nullptr; }
    list<bytes *> *rsplit(bytes *sep=0, __ss_int maxsplit=-1) { return nullptr; }
    tuple2<bytes *, bytes *> *rpartition(bytes *sep) { return nullptr; }
    tuple2<bytes *, bytes *> *partition(bytes *sep) { return nullptr; }
    list<bytes *> *splitlines(__ss_int keepends = 0) { return nullptr; }

    // C string operations
    char *c_str() const { return nullptr; }
    __ss_int __fixstart(size_t a, __ss_int b) { return 0; }
    __ss_int __checkneg(__ss_int i) { return 0; }

    // Case operations
    bytes *upper() { return nullptr; }
    bytes *lower() { return nullptr; }
    bytes *title() { return nullptr; }
    bytes *capitalize() { return nullptr; }

    // Type checking
    __ss_bool istitle() { return false; }
    __ss_bool isspace() { return false; }
    __ss_bool isalpha() { return false; }
    __ss_bool isdigit() { return false; }
    __ss_bool islower() { return false; }
    __ss_bool isupper() { return false; }
    __ss_bool isalnum() { return false; }
    __ss_bool __ss_isascii() { return false; }

    // String checks
    __ss_bool startswith(bytes *s, __ss_int start=0) { return false; }
    __ss_bool startswith(bytes *s, __ss_int start, __ss_int end) { return false; }
    __ss_bool endswith(bytes *s, __ss_int start=0) { return false; }
    __ss_bool endswith(bytes *s, __ss_int start, __ss_int end) { return false; }

    // Search operations
    __ss_int find(bytes *s, __ss_int a=0) { return 0; }
    __ss_int find(bytes *s, __ss_int a, __ss_int b) { return 0; }
    __ss_int find(__ss_int i, __ss_int a=0) { return 0; }
    __ss_int find(__ss_int i, __ss_int a, __ss_int b) { return 0; }

    __ss_int rfind(bytes *s, __ss_int a=0) { return 0; }
    __ss_int rfind(bytes *s, __ss_int a, __ss_int b) { return 0; }
    __ss_int rfind(__ss_int i, __ss_int a=0) { return 0; }
    __ss_int rfind(__ss_int i, __ss_int a, __ss_int b) { return 0; }

    __ss_int count(bytes *b, __ss_int start=0) { return 0; }
    __ss_int count(__ss_int b, __ss_int start=0) { return 0; }
    __ss_int count(bytes *b, __ss_int start, __ss_int end) { return 0; }
    __ss_int count(__ss_int b, __ss_int start, __ss_int end) { return 0; }

    // Index operations
    __ss_int index(bytes *s, __ss_int a=0) { return 0; }
    __ss_int index(bytes *s, __ss_int a, __ss_int b) { return 0; }
    __ss_int index(__ss_int i, __ss_int a=0) { return 0; }
    __ss_int index(__ss_int i, __ss_int a, __ss_int b) { return 0; }

    __ss_int rindex(bytes *s, __ss_int a=0) { return 0; }
    __ss_int rindex(bytes *s, __ss_int a, __ss_int b) { return 0; }
    __ss_int rindex(__ss_int i, __ss_int a=0) { return 0; }
    __ss_int rindex(__ss_int i, __ss_int a, __ss_int b) { return 0; }

    // Formatting operations
    bytes *expandtabs(__ss_int tabsize=8) { return nullptr; }
    bytes *swapcase() { return nullptr; }
    bytes *replace(bytes *a, bytes *b, __ss_int c=-1) { return nullptr; }
    bytes *center(__ss_int width, bytes *fillchar=0) { return nullptr; }
    bytes *zfill(__ss_int width) { return nullptr; }
    bytes *ljust(__ss_int width, bytes *fillchar=0) { return nullptr; }
    bytes *rjust(__ss_int width, bytes *fillchar=0) { return nullptr; }
    str *hex(str *sep=0) { return nullptr; }

    // Object operations
    str *__str__() { return nullptr; }
    str *__repr__() { return nullptr; }
    __ss_bool __contains__(__ss_int) { return false; }
    __ss_bool __contains__(bytes *) { return false; }
    __ss_bool __eq__(pyobj *s) { return false; }
    long __hash__() { return 0; }
    __ss_bool __ctype_function(int (*cfunc)(int)) { return false; }

    // Arithmetic operations
    bytes *__add__(bytes *b) { return nullptr; }
    bytes *__mul__(__ss_int n) { return nullptr; }

    // Iteration support
    inline bool for_in_has_next(size_t i) { return false; }
    inline __ss_int for_in_next(size_t &i) { return 0; }

    // Bytearray operations
    void *clear() { return nullptr; }
    void *append(__ss_int i) { return nullptr; }
    __ss_int pop(__ss_int i=-1) { return 0; }
    bytes *copy() { return nullptr; }
    void *extend(pyiter<__ss_int> *p) { return nullptr; }
    void *reverse() { return nullptr; }
    void *insert(__ss_int index, __ss_int item) { return nullptr; }
    void *__setitem__(__ss_int i, __ss_int e) { return nullptr; }
    void *__delitem__(__ss_int i) { return nullptr; }
    void *remove(__ss_int i) { return nullptr; }
    bytes *__iadd__(bytes *b) { return nullptr; }
    bytes *__imul__(__ss_int n) { return nullptr; }
    void *__setslice__(__ss_int x, __ss_int l, __ss_int u, __ss_int s, pyiter<__ss_int> *b) { return nullptr; }
    void *__delete__(__ss_int x, __ss_int l, __ss_int u, __ss_int s) { return nullptr; }
};

// Helper functions
template<class T> bytes *__bytes(T *t) { return nullptr; }
bytes *__bytes(bytes *b) { return nullptr; }
bytes *__bytes(__ss_int t) { return nullptr; }
bytes *__bytes() { return nullptr; }

template<class T> bytes *__bytearray(T *t) { return nullptr; }
bytes *__bytearray(bytes *b) { return nullptr; }
bytes *__bytearray(__ss_int t) { return nullptr; }
bytes *__bytearray() { return nullptr; }

} // namespace shedskin

#endif // SHEDSKIN_BYTES_HPP
