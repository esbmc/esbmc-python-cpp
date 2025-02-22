# esbmc-python-cpp
This is a shedskin wrapper for the ESBMC model checker. It is a work in progress and is not yet ready for use.

How to build

1. Clone the repository
1. Run ```./install.sh```
1. Run ```./regression.sh``` to run regression tests
1. Use ```./verify.sh``` against python files in the examples folder or elsewhere
1. Run ```./esbmc_python_regressions.sh``` to run esbmc tests


The new **LLM** option. It allows one to:

1. Convert all the shedskin syntax to C code which allows verification to run MUCH faster.
1. Adds option to verify thread safe code in python, in this case a direct conversion is made from python to verifiable C code.
1. To run it, you need a token to openrouter or to deploy an LLM locally
1. ```./verify.sh --llm <filename>```

Recommended options:

1. ```./verify.sh --llm --model openrouter/deepseek/deepseek-chat examples/example_deadlock_bug.py``` (to save cloud cost)
1. ```./verify.sh --llm --translation fast examples/example_deadlock_bug.py``` (to translate code fast with google gemini)
1. ```./verify.sh --llm examples/example_deadlock_bug.py``` (Using the expensive Claude Antrophic LLM)
1. ```./verify.sh --llm --model <custom model including locally deployed LLMs> examples/example_deadlock_bug.py```

Validate code translation, will validate the code translation, and adjust if not translated ideally:

1. ````./verify.sh --llm examples/example_15_dictionary.py --validate-translation````

Run with local LLMs:

1. ````./verify.sh jpl-examples/list_comprehension_complex.py --llm --model ollama/qwen2.5-coder:32b --direct````
or 
````./verify.sh jpl-examples/list_comprehension_complex.py --llm --model ollama/qwen2.5-coder:7b --direct````

Note that running with a larger model will take longer to run, but will be more accurate.
