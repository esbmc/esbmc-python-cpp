# esbmc-python-cpp
This is a shedskin wrapper for the ESBMC model checker. It is a work in progress and is not yet ready for use.

How to build

1. Clone the repository
1. Run ./install.sh
1. Run ./regression.sh to run regression tests
1. Use ./verify.sh against python files in the examples folder or elsewhere
1. Run ./esbmc_python_regressions.sh to run esbmc tests


The new **LLM** option. It allows one to:

1. Convert all the shedskin syntax to C code which allows verification to run MUCH faster.
1. Adds option to verify thread safe code in python, in this case a direct conversion is made from python to verifiable C code.
1. To run it, you need a token to openrouter or to deploy an LLM locally
1. ./verify.sh --llm <filename>
