#ifndef __RANDOM_HPP
#define __RANDOM_HPP

#include "builtin.hpp"
#include "math.hpp"
#include "time.hpp"

namespace shedskin {

// Forward declarations
class Random;
class WichmannHill;

// Constants
const int UPPER = 100;
const double LOG4 = 1.3862943611198906;
const double SG_MAGICCONST = 2.504077396776274;
const int BPF = 30;  
const int MATRIX_A = 0x9908b0df;
const int M = 397;
const int LOWER = 0;
const int N = 624;
const unsigned int MAXWIDTH = 1U << BPF;
const double NV_MAGICCONST = 1.7155277699214135;
const int MAXBITS = 32;

class Random {
protected:
    unsigned long long state;
    
public:
    Random() : state(1) {}
    explicit Random(__ss_int seed) : state(seed) {}
    
    virtual double random() {
        state = (state * 1103515245 + 12345) & 0x7fffffff;
        return static_cast<double>(state) / 0x7fffffff;
    }

    __ss_int randrange(__ss_int stop) {
        return randrange(0, stop, 1);
    }

    __ss_int randrange(__ss_int start, __ss_int stop) {
        return randrange(start, stop, 1);
    }

    __ss_int randrange(__ss_int start, __ss_int stop, __ss_int step) {
        if (step == 0) {
            throw new ValueError(new str("zero step for randrange()"));
        }
        __ss_int width = stop - start;
        if (step == 1 && width > 0) {
            return start + static_cast<__ss_int>(random() * width);
        }
        if (step == 1) {
            throw new ValueError(new str("empty range for randrange()"));
        }
        __ss_int n;
        if (step > 0) {
            n = (width + step - 1) / step;
        } else if (step < 0) {
            n = (width + step + 1) / step;
        } else {
            throw new ValueError(new str("zero step for randrange()"));
        }
        if (n <= 0) {
            throw new ValueError(new str("empty range for randrange()"));
        }
        return start + (step * static_cast<__ss_int>(random() * n));
    }

    __ss_int randint(__ss_int a, __ss_int b) {
        return randrange(a, b + 1);
    }

    __ss_float uniform(__ss_float a, __ss_float b) {
        return a + (b - a) * random();
    }
    
    __ss_int getrandbits(__ss_int k) {
        if (k <= 0) return 0;
        if (k > MAXBITS) throw new ValueError(new str("k exceeds size of int"));
        return static_cast<__ss_int>(random() * (1LL << k));
    }
};

class WichmannHill : public Random {
private:
    __ss_int x, y, z;
    
public:
    WichmannHill() : x(1), y(1), z(1) {}
    
    explicit WichmannHill(__ss_int seed) {
        x = seed % 30268;
        y = (seed * 171) % 30307;
        z = (seed * 172) % 30323;
        if (x == 0) x = 1;
        if (y == 0) y = 1;
        if (z == 0) z = 1;
    }

    double random() override {
        x = (171 * x) % 30269;
        y = (172 * y) % 30307;
        z = (170 * z) % 30323;
        
        double r = __mods((__ss_float)x/30269.0 + (__ss_float)y/30307.0 + (__ss_float)z/30323.0, 1.0);
        return r >= 0.0 ? r : r + 1.0;
    }
};

// Global instance
extern Random* _inst;

// Global functions that delegate to _inst
inline double random() { return _inst->random(); }
inline __ss_int randrange(__ss_int stop) { return _inst->randrange(stop); }
inline __ss_int randrange(__ss_int start, __ss_int stop) { return _inst->randrange(start, stop); }
inline __ss_int randrange(__ss_int start, __ss_int stop, __ss_int step) { 
    return _inst->randrange(start, stop, step); 
}
inline __ss_int randint(__ss_int a, __ss_int b) { return _inst->randint(a, b); }
inline __ss_int getrandbits(__ss_int k) { return _inst->getrandbits(k); }

void __init();

} // namespace shedskin

namespace __random__ = shedskin;

#endif