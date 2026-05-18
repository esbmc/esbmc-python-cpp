# Enhanced Verification Agent

An iterative, multi-tool Python verification agent built on Claude's tool-use API. It orchestrates static analysis (mypy, pylint, flake8, bandit), runtime checks (Python interpreter, deadlock detector), AST inspection, optional fine-tuned analysis, and formal verification via ESBMC (with LLM-driven Python-to-C translation).

## Prerequisites

- Python 3.10+ (3.12 recommended)
- An Anthropic API key (https://console.anthropic.com/)
- Optional: [ESBMC](https://github.com/esbmc/esbmc) installed on `PATH` (or pointed to via `--esbmc-path` / `ESBMC_PATH`) for formal C verification

## Setup

### 1. Install dependencies

Automated (recommended):

```bash
cd agent
./setup.sh
```

Or manually:

```bash
cd agent
python3 -m venv venv
source venv/bin/activate
pip install -r requirements.txt
```

### 2. Configure your Anthropic API key

The agent reads `ANTHROPIC_API_KEY` from the environment (it also auto-loads a `.env` file via `python-dotenv`).

**Option A — `.env` file (preferred):**

```bash
echo 'ANTHROPIC_API_KEY=sk-ant-...' > .env
```

Make sure `.env` is gitignored. The `setup.sh` script will create one for you and add it to `.gitignore`.

**Option B — shell export:**

```bash
export ANTHROPIC_API_KEY='sk-ant-...'
```

Add the line to `~/.zshrc` (or `~/.bashrc`) to persist it across sessions.

**Verify the key is visible:**

```bash
echo $ANTHROPIC_API_KEY
```

If the agent cannot find the key it exits with:

```
❌ Error: ANTHROPIC_API_KEY not found
```

### 3. (Optional) Configure ESBMC

```bash
# Either put esbmc on PATH, or:
export ESBMC_PATH=/path/to/esbmc
# Or pass --esbmc-path on the command line.
```

## Running the agent

Activate the venv first:

```bash
source venv/bin/activate
```

### Demo run (no file)

```bash
python enhanced_verification_agent.py
```

Runs the built-in "Type-Annotated Division" demo case.

### Verify a Python file

```bash
python enhanced_verification_agent.py example_test.py
```

### Common command examples

```bash
# Increase the iteration budget
python enhanced_verification_agent.py mycode.py --max-iterations 15

# Point at a custom ESBMC binary
python enhanced_verification_agent.py mycode.py --esbmc-path /usr/local/bin/esbmc

# Force formal verification (Python → C → ESBMC)
python enhanced_verification_agent.py mycode.py --force-esbmc

# Force a specific subset of static-analysis tools
python enhanced_verification_agent.py mycode.py --force-mypy --force-bandit

# Threading code: use the runtime deadlock detector
python enhanced_verification_agent.py example_race_condition.py --force-deadlock

# Use the fine-tuned ESBMC analyzer (requires adapter weights)
export FINETUNED_ADAPTER_PATH=./finetune/models/test_lora
python enhanced_verification_agent.py mycode.py --use-finetuned --force-finetuned
```

### Available flags

| Flag | Effect |
|------|--------|
| `--max-iterations N` | Cap the verification loop (default 10) |
| `--esbmc-path PATH` | Path to the ESBMC binary |
| `--force-ast` | Force AST analysis |
| `--force-mypy` | Force mypy type checking |
| `--force-pylint` | Force pylint |
| `--force-flake8` | Force flake8 |
| `--force-bandit` | Force bandit security scan |
| `--force-python` | Force running the code in the Python interpreter |
| `--force-deadlock` | Force the runtime deadlock detector |
| `--force-esbmc` | Force Python→C conversion + ESBMC |
| `--use-finetuned` | Load the fine-tuned analyzer |
| `--force-finetuned` | Force fine-tuned analyzer in the first iteration (implies `--use-finetuned`) |

Full help:

```bash
python enhanced_verification_agent.py --help
```

## Outputs

When ESBMC is exercised, the agent writes:

- `converted_code.c` — LLM-generated C from your Python source
- `esbmc_verify.c` — the file actually handed to ESBMC

The summary at the end of each run lists iteration count, tools used, ESBMC checks enabled, and a reproduction command you can re-run by hand.
