# Hybrid Verification Flow

ESBMC-Python-CPP supports three paths for verifying Python programs with [ESBMC](https://esbmc.org/). The term "hybrid" refers to the combination of these paths, which can be mixed depending on the nature of the program being verified.

```
Python source
      │
      ├─── [Path 1] Shedskin ──────────────► C++ ──► ESBMC
      │
      ├─── [Path 2] LLM conversion ────────► C   ──► ESBMC
      │
      └─── [Path 3] Dynamic tracing ───────► C   ──► ESBMC
```

## Path 1 — Static conversion via Shedskin

`verify_exec_cpp.sh` drives this path.

1. **Shedskin** compiles the Python source to C++ using whole-program type inference.
2. The resulting C++ is compiled with `make`.
3. ESBMC verifies the compiled C++ binary for safety violations.

This path works well for programs that fall within Shedskin's statically-typed Python subset. See [`shedskin.md`](shedskin.md) for the Docker environment and usage examples.

## Path 2 — LLM-based conversion to C

`verify.sh` drives this path.

1. An LLM (cloud or local) receives the Python source and a structured prompt from `prompts/python_prompt.txt`.
2. The LLM produces a C translation of the Python program.
3. ESBMC checks whether the C file parses correctly (`--parse-tree-only`). If it does not, the LLM is asked to fix the translation (up to 10 attempts).
4. Once the translation compiles, ESBMC runs the full verification.

Optional validation step (`--validate-translation`): after the initial conversion, the LLM compares the original Python and the translated C side-by-side and iterates until any remaining semantic gaps are resolved.

This path supports features that Shedskin cannot handle, including threading (`pthread`), dictionaries, dynamic polymorphism, and arbitrary standard-library usage.

### Supported LLM backends

| Flag | Description |
|------|-------------|
| `--llm` | Cloud model via OpenRouter or OpenAI |
| `--local-llm` | Local model via Ollama or MLX (Mac) |
| `--model <id>` | Override the default model |

## Path 3 — Dynamic execution tracing

`dynamic_trace.py` drives this path.

1. The Python program is executed under Python's built-in trace hook, capturing the concrete execution path.
2. The recorded trace is summarised and passed to the LLM, which produces a C representation of that specific path.
3. ESBMC verifies the path-specific C code.

This path is useful when full static translation is not feasible but the property of interest is reachable along a known execution path.

## Choosing a path

| Scenario | Recommended path |
|----------|-----------------|
| Shedskin-compatible Python, no threading | Path 1 (fastest, no LLM required) |
| General Python, threading, complex types | Path 2 (LLM-based) |
| Large codebase, single path of interest | Path 3 (dynamic tracing) |

## Relationship to esbmc-python

[esbmc-python](https://github.com/esbmc/esbmc/tree/master/src/python-frontend) is ESBMC's built-in Python front-end. It parses Python source directly inside ESBMC without any intermediate translation step. ESBMC-Python-CPP is complementary: it handles Python constructs that the front-end does not yet support by first translating the program to C or C++ before handing it to ESBMC.
