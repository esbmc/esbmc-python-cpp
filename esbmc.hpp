#ifndef __ESBMC_HPP
#define __ESBMC_HPP

using namespace __shedskin__;
namespace __esbmc__ {

class Thread;
class Topic;


extern str *__name__;


extern class_ *cl_Thread;
class Thread : public pyobj {
public:
    Thread() { this->__class__ = cl_Thread; }
};

extern class_ *cl_Topic;
class Topic : public pyobj {
public:
    Topic() { this->__class__ = cl_Topic; }
};

extern void * default_0;
extern void * default_1;
extern void * default_2;
extern void * default_3;
void __init();
__ss_int nondet_int();

} // module namespace
#endif
