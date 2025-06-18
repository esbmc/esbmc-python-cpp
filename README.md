# ESBMC-Python-CPP: Bridging Python to Verified C/++ using ESBMC

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
git clone https://github.com/YOUR_USERNAME/esbmc-python-cpp.git
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
./verify.sh --llm <filename>
```

### Recommended Options

| Description | Command |
|------------|---------|
| Use DeepSeek via OpenRouter (cheap & efficient) | `./verify.sh --llm --model openrouter/deepseek/deepseek-chat examples/example_deadlock_bug.py` |
| Use Gemini for fast translation | `./verify.sh --llm --translation fast examples/example_deadlock_bug.py` |
| Use Claude (high accuracy, more expensive) | `./verify.sh --llm examples/example_deadlock_bug.py` |
| Use a custom or local model | `./verify.sh --llm --model <custom_model> examples/example_deadlock_bug.py` |

### Validate the LLM Translation

```bash
./verify.sh --llm examples/example_15_dictionary.py --validate-translation
```

---

## 🧵 Dynamic Execution Tracing

Trace and verify live execution paths using Python's built-in tracing:

```bash
python dynamic_trace.py --model openrouter/deepseek/deepseek-chat aws_examples/chalice_awsclient.py
```

Or use Docker:

```bash
python dynamic_trace.py --docker --image esbmc-image --model openrouter/deepseek/deepseek-chat aws_examples/chalice_awsclient.py
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


