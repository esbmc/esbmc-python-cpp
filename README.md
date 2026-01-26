# ESBMC-Python-CPP: Bridging Python to Verified C++ using ESBMC

**ESBMC-Python-CPP** is a work-in-progress toolkit that bridges Python code and C/++ verification through the [ESBMC](https://esbmc.org/) model checker. It supports three primary approaches for converting and analyzing Python code:

1. **Static Conversion via Shedskin**
   Converts Python to C++ code using [Shedskin](https://github.com/shedskin/shedskin).
   - See [`docs/shedskin.md`](docs/shedskin.md) for a reproducible Docker setup and usage examples.
   - See [`docs/hybrid-flow.md`](docs/hybrid-flow.md) for a detailed explanation of the hybrid verification flow.

2. **LLM-Based Conversion from Python to C**
   Uses local or remote LLMs to directly convert Python code to verifiable C code.

3. **Dynamic Tracing**
   Traces a specific execution path to analyze behavior during runtime.

---

## 🔧 Installation for Mac OS X

```bash
git clone https://github.com/esbmc/esbmc-python-cpp.git
cd esbmc-python-cpp/mac
./setup-esbmc-mac.sh
./esbmc-mac.sh to run esbmc

To install the local model GLM 4.6 air:

cd llm-mlx
./start_daemon.sh to start the daemon
./stop_daemon.sh stops the daemon process
```

### Using ESBMC on Mac

For Mac users, you can use the provided `esbmc-mac.sh` wrapper:

```bash
# Use the Mac-specific ESBMC executable
./verify.sh --esbmc-exec ./mac/esbmc-mac.sh <filename>

# Example with local LLM
./verify.sh --esbmc-exec ./mac/esbmc-mac.sh --local-llm <filename>

# Example with cloud LLM
./verify.sh --esbmc-exec ./mac/esbmc-mac.sh --llm --model openrouter/z-ai/glm-4.6 <filename>
```

---

## 🚀 Usage

### ✅ Run Regression Tests

```bash
# Run with default cloud LLM
./regression.sh

# Run with local LLM
./regression.sh --local-llm

# Run with specific model
./regression.sh --model openrouter/z-ai/glm-4.6

# Run with Mac ESBMC and local LLM
./regression.sh --esbmc-exec ./mac/esbmc-mac.sh --local-llm
```

### 🔍 Verify Python Code

```bash
# Basic verification (uses default cloud LLM)
./verify.sh <path_to_python_file>

# With Mac ESBMC executable
./verify.sh --esbmc-exec ./mac/esbmc-mac.sh <path_to_python_file>

# With cloud LLM
./verify.sh --llm --model openrouter/z-ai/glm-4.6 <path_to_python_file>

# With local LLM
./verify.sh --local-llm <path_to_python_file>
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
- Supports both **cloud LLMs** and **locally deployed** LLMs.

### Cloud LLM Usage

Use cloud-based models like OpenRouter, OpenAI, or others:

```bash
# Default cloud model (openrouter/z-ai/glm-4.6)
./verify.sh --llm <filename>

# Specify a cloud model
./verify.sh --llm --model openrouter/anthropic/claude-3-sonnet <filename>
./verify.sh --llm --model openai/gpt-4 <filename>
./verify.sh --llm --model openrouter/google/gemini-2.0-flash-001 <filename>
```

### Local LLM Usage

Use locally deployed models via aider.sh:

```bash
# Default local model (openai/mlx-community/GLM-4.5-Air-4bit)
./verify.sh --local-llm <filename>

# Specify a local model
./verify.sh --local-llm --model llama-3.1-8b <filename>
./verify.sh --local-llm --model qwen2.5-coder:32b <filename>
```

### Validate the LLM Translation

```bash
# Cloud LLM validation
./verify.sh --llm --model openrouter/z-ai/glm-4.6 examples/example_15_dictionary.py --validate-translation

# Local LLM validation
./verify.sh --local-llm examples/example_15_dictionary.py --validate-translation
```

### Available Models

#### Cloud Models (via --llm)
- `openrouter/z-ai/glm-4.6` (default)
- `openrouter/anthropic/claude-3-sonnet`
- `openrouter/anthropic/claude-3-haiku`
- `openrouter/google/gemini-2.0-flash-001`
- `openrouter/deepseek/deepseek-r1`
- `openai/gpt-4`
- `openai/gpt-3.5-turbo`

#### Local Models (via --local-llm)
- `openai/mlx-community/GLM-4.5-Air-4bit` (default for Mac)
- `llama-3.1-8b`
- `qwen2.5-coder:7b`
- `qwen2.5-coder:32b`
- Any model available via your local LLM server

---

## 🧵 Dynamic Execution Tracing

Trace and verify live execution paths using Python's built-in tracing:

```bash
# With cloud LLM
python3 dynamic_trace.py --model openrouter/z-ai/glm-4.6 aws_examples/chalice_awsclient.py

# With local LLM
python3 dynamic_trace.py --local-llm --model qwen2.5-coder:7b aws_examples/chalice_awsclient.py

# Or use Docker
python3 dynamic_trace.py --docker --image esbmc-image --model openrouter/z-ai/glm-4.6 aws_examples/chalice_awsclient.py
```

---

## 🖥️ Running with Local LLMs

### Option 1: Using Ollama

#### Step 1: Install Ollama

```bash
brew install ollama
```

#### Step 2: Start Ollama Server

```bash
ollama serve
```

#### Step 3: Choose a Model

Browse: https://ollama.com/library

Pull a model:

```bash
ollama pull <model_name>
```

Tested models:
- `qwen2.5-coder:7b`
- `qwen2.5-coder:32b`

#### Example with Ollama

```bash
./verify.sh --local-llm --model qwen2.5-coder:32b jpl-examples/list_comprehension_complex.py --direct
```

### Option 2: Using MLX (Mac Recommended)

For Mac users, the MLX-based local LLM is pre-configured:

```bash
# Start the MLX daemon (one-time setup)
cd mac/llm-mlx
./start_daemon.sh

# Use the default MLX model
./verify.sh --local-llm <filename>

# Or specify the MLX model explicitly
./verify.sh --local-llm --model openai/mlx-community/GLM-4.5-Air-4bit <filename>
```

### Option 3: Using Custom Local LLM Server

If you have a custom LLM server running:

```bash
# Set environment variables for your server
export OPENAI_API_KEY=dummy
export OPENAI_API_BASE=http://localhost:8080/v1

# Run with local LLM
./verify.sh --local-llm --model your-model-name <filename>
```

> 📁 *Larger models offer better accuracy but are slower to run.*
> 🍎 *Mac users: The MLX option (GLM-4.5-Air-4bit) is optimized for Apple Silicon*

---

## 🐳 Using Docker with Shedskin

For a fully reproducible environment with Shedskin and ESBMC, you can use the provided Dockerfile:

```bash
# 1. Rebuild the image (force refresh of dependencies)
docker build --no-cache -t esbmc-shedskin .
# or
make docker-build

# 2. Open an interactive shell with examples copied to /tmp/shedskin-smoke/examples
make docker-run-example

# 3. Inside the container (already in /tmp/shedskin-smoke/examples):
shedskin shedskin_runtime_smoke.py
make
./shedskin_runtime_smoke
```

You can replace `shedskin_runtime_smoke.py` with any other Python example that is compatible with Shedskin.

---

## 📬 Contact & Contributions

This project is under active development. Feedback, issues, and contributions are welcome!

