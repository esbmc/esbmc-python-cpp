#ifndef SHEDSKIN_STRING_HPP
#define SHEDSKIN_STRING_HPP

namespace shedskin {
    class str;  // Forward declaration
}

namespace string {
    using namespace shedskin;
    // String constants
    extern str* ascii_letters;
    extern str* ascii_uppercase;
    extern str* ascii_lowercase;
    extern str* whitespace;
    extern str* punctuation;
    extern str* printable;
    extern str* hexdigits;
    extern str* octdigits;
    extern str* digits;
    
    // String manipulation functions
    str* capwords(str* s, str* sep=0) { return nullptr; }
    
    // Module initialization
    void __init() {}
} // namespace string

#endif // SHEDSKIN_STRING_HPP