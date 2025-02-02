#ifndef __RANDOM_HPP
#define __RANDOM_HPP

#include "builtin.hpp"
#include "math.hpp"
#include "time.hpp"

namespace shedskin {

// Forward declarations
class Random;
class WichmannHill;

// Constants - fixed to work with int
constexpr int UPPER = 100;
constexpr double LOG4 = 1.3862943611198906;
constexpr double SG_MAGICCONST = 2.504077396776274;
constexpr int BPF = 30;  // Reduced from 53 to fit in int
constexpr int MATRIX_A = 0x9908b0df;
constexpr int M = 397;
constexpr int LOWER = 0;
constexpr int N = 624;
constexpr unsigned int MAXWIDTH = 1U << BPF;  // Made unsigned to handle shift
constexpr double NV_MAGICCONST = 1.7155277699214135;
constexpr int MAXBITS = 32;

// Simple random number generator 
class Random {
protected:
    unsigned long long state;
    
public:
    Random() : state(1) {}
    explicit Random(__ss_int seed) : state(seed) {}

    virtual double random() {
        state = (state * 6364136223846793005ULL + 1442695040888963407ULL);
        return (state >> 11) * (1.0 / 9007199254740992.0);
    }

    __ss_int randint(__ss_int a, __ss_int b) {
        return a + (__ss_int)(random() * (b - a + 1));
    }

    __ss_float uniform(__ss_float a, __ss_float b) {
        return a + (b - a) * random();
    }

    __ss_int getrandbits(__ss_int k) {
        if (k <= 0) return 0;
        return (__ss_int)(random() * (1LL << k));
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
Random* _inst = new Random();

// Global functions that delegate to _inst
inline double random() { return _inst->random(); }
inline __ss_int randint(__ss_int a, __ss_int b) { return _inst->randint(a, b); }
inline __ss_int getrandbits(__ss_int k) { return _inst->getrandbits(k); }

} // namespace shedskin

// Provide the namespace that the generated code expects
namespace __random__ = shedskin;

#endif // __RANDOM_HPP