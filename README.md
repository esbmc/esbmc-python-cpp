# ESBMC-Python-CPP: Bridging Python to Verified C++ using ESBMC

**ESBMC-Python-CPP** is a work-in-progress toolkit that bridges Python code and C/++ verification through the [ESBMC](https://esbmc.org/) model checker. It supports three primary approaches for converting and analyzing Python code:

1. **Static Conversion via Shedskin**  
   Converts Python to C++ code using [Shedskin](https://github.com/shedskin/shedskin).

2. **LLM-Based Conversion from Python to C**  
   Uses local or remote LLMs to directly convert Python code to verifiable C code.

3. **Dynamic Tracing**  
   Traces a specific execution path to analyze behavior during runtime.

---

## 🔧 Installation

```bash
git clone https://github.com/esbmc/esbmc-python-cpp.git
cd esbmc-python-cpp
./install.sh
```

---

## 🚀 Usage

### ✅ Run Regression Tests

```bash
./regression.sh
```

### 🔍 Verify Python Code

```bash
./verify.sh <path_to_python_file>
```

Use example files from the `examples/` directory or your own.

### 🥪 Run ESBMC-Specific Tests

```bash
./esbmc_python_regressions.sh
```

---

## 🤖 Using the LLM Backend

LLM mode allows faster and more flexible code verification:

- Converts Shedskin-style Python to pure C.
- Enables verification of **thread-safe** code.
- Supports cloud and **locally deployed** LLMs.

### Basic Command

```bash
./verify.sh --llm --model <model> <filename>
```

Example:

```bash
./verify.sh --llm --model ollama_chat/qwen2.5-coder:7b examples/example_deadlock_bug.py
```

### Validate the LLM Translation

```bash
./verify.sh --llm --model ollama_chat/qwen2.5-coder:7b examples/example_15_dictionary.py --validate-translation
```

---

## 🧵 Dynamic Execution Tracing

Trace and verify live execution paths using Python's built-in tracing:

```bash
python3 dynamic_trace.py --model ollama_chat/qwen2.5-coder:7b aws_examples/chalice_awsclient.py
```

Or use Docker:

```bash
python3 dynamic_trace.py --docker --image esbmc-image --model ollama_chat/qwen2.5-coder:7b aws_examples/chalice_awsclient.py
```

---

## 🖥️ Running with Local LLMs via Ollama

### Step 1: Install Ollama

```bash
brew install ollama
```

### Step 2: Start Ollama Server

```bash
ollama serve
```

### Step 3: Choose a Model

Browse: https://ollama.com/library

Pull a model:

```bash
ollama pull <model_name>
```

Tested models:
- `qwen2.5-coder:7b`
- `qwen2.5-coder:32b`

### Example

```bash
./verify.sh jpl-examples/list_comprehension_complex.py --llm --model ollama_chat/qwen2.5-coder:32b --direct
```

> 📁 *Larger models offer better accuracy but are slower to run.*

---

## 📬 Contact & Contributions

This project is under active development. Feedback, issues, and contributions are welcome!


