# Plan — Integrate ESBMC-Python (Direct Frontend) into EVA

## 1. Motivation

EVA currently verifies Python by LLM-translating it to C and invoking ESBMC on
the translated artefact (`convert_python_to_c` → `run_esbmc`). This is robust
for arithmetic/bounds bugs but has two known weaknesses called out in the
AISOLA-2026 paper:

1. **No semantic-equivalence guarantee.** Spurious counterexamples are
   possible; EVA mitigates with a Python-interpreter cross-check, not a proof.
2. **Translation cost dominates the loop.** Each ESBMC invocation depends on
   an LLM re-generating C; iterative refinement multiplies LLM tokens.

ESBMC's built-in Python front-end (referred to as **ESBMC-Python**, Farias et
al., ISSTA 2024 [ref. 35 in the paper], hosted under
`src/python-frontend/` in the upstream ESBMC repo) parses Python *directly*
into ESBMC's IR. It avoids translation, gives semantic faithfulness on the
Python constructs it supports, and removes the LLM from the verification
inner loop. Its weakness is coverage: it does not yet handle every Python
construct EVA's translation path can. The two are complementary, which is
exactly the framing the project's README already adopts.

The goal: **add ESBMC-Python as a peer formal-verification tool inside EVA's
orchestrator**, alongside the existing `convert_python_to_c` + `run_esbmc`
pipeline, and let the LLM choose between them per-program (or run both and
cross-check).

## 2. Scope and non-goals

In scope:
- A new EVA tool `run_esbmc_python` that invokes ESBMC directly on the
  `.py` source.
- Orchestrator prompt + decision-logic update so the LLM picks the right
  backend.
- A coverage probe (lightweight AST feature classifier) that predicts whether
  ESBMC-Python will accept the file.
- Cross-validation mode: run both backends when they disagree, surface the
  divergence.
- Regression tests on the existing 23-program benchmark + a small ESBMC-Python-
  native subset (Ethereum Consensus examples shipped upstream).
- Result-normalization layer so both backends emit the same JSON schema that
  the orchestrator already consumes.

Out of scope (for this iteration):
- Modifying ESBMC-Python itself.
- Proving semantic equivalence between the two pipelines.
- Multi-file Python projects (paper §6 future work).
- Re-training the fine-tuned DeepSeek analyzer.

## 3. Architecture changes

EVA's tool registry today (see `agent/enhanced_verification_agent.py:47-163`):

```
run_python_interpreter, run_mypy, run_pylint, run_bandit, run_flake8,
analyze_ast, run_deadlock_detector,
convert_python_to_c, run_esbmc,         # ← current formal-verification path
run_finetuned_analyzer
```

Proposed registry after the change:

```
... (unchanged) ...
analyze_ast,                            # extended: emits backend-capability hint
run_deadlock_detector,
convert_python_to_c, run_esbmc,         # path A: translate-then-verify
run_esbmc_python,                       # path B: direct Python verification (NEW)
cross_validate_backends,                # NEW: orchestrator helper, see §3.4
run_finetuned_analyzer
```

### 3.1 `run_esbmc_python` tool

- **Input schema** (mirrors `run_esbmc` so the orchestrator can swap easily):
  - `code: str` — the original Python source.
  - `check_overflow`, `check_bounds`, `check_div_by_zero`,
    `check_memory_leak`, `check_pointer` — boolean flags.
  - `unwind: int` (default 10), `timeout: int` (default 60).
  - `extra_args: list[str]` — escape hatch for less-common ESBMC flags.

- **Behaviour**:
  1. Write the Python source to a tempfile.
  2. Invoke ESBMC with `--python` (the front-end activator used by the upstream
     `python-frontend`), plus translated `--overflow-check`, `--bounds-check`,
     `--unwind N`, `--memory-leak-check`, etc. — same flag-mapping table that
     `_run_esbmc_attempt` already builds for the C path, lifted into a shared
     helper.
  3. Reuse `_esbmc_timed_out` and `_truncate_esbmc_output` from the existing
     ESBMC runner — no duplication.
  4. Parse verdict using the same `_determine_if_verified` heuristic — ESBMC's
     terminal output format is identical across front-ends.
  5. Return the same `Dict` shape as `_run_esbmc`:
     `{tool, success, verified, output, witness, checks_run, backend:
     "esbmc-python"}`.

- **Resilience**: if ESBMC reports a Python construct it cannot lower
  (e.g. "unsupported AST node"), capture that as a structured
  `unsupported_construct` flag in the result rather than a generic failure.
  The orchestrator treats this as a *fallback signal* — switch to path A.

### 3.2 Orchestrator decision logic

Today the LLM is told (paper Fig. 3): "for arithmetic → ESBMC overflow, for
arrays → ESBMC bounds, for threading → deadlock detector." The new prompt
will add a *backend pre-selection* rule placed before the ESBMC call:

```
Before invoking any ESBMC backend:
  - If the AST contains ONLY: numeric ops, list/dict literals, ints, bools,
    bounded loops, asserts, and esbmc.nondet_*() calls,
    → prefer run_esbmc_python (direct, faster, no translation step).
  - If the AST contains: classes with inheritance, decorators beyond
    @dataclass, dynamic attribute access, metaprogramming, comprehensions
    that build heterogeneous types, generators, or numpy/scipy calls,
    → use convert_python_to_c + run_esbmc (LLM bridges the gap).
  - If unsure, try run_esbmc_python first; on `unsupported_construct`, fall
    back to convert_python_to_c.
  - For threading code, the rule is unchanged: run_deadlock_detector.
```

This selection runs once per program; the conversation history then
prevents re-trying the wrong backend.

`analyze_ast` is extended to compute a single boolean
`likely_esbmc_python_compatible` plus a list of unsupported features it
spotted, so the LLM has a structured hint rather than relying on the
free-form rule above.

### 3.3 Shared ESBMC invocation helper

Factor the current `_run_esbmc_attempt` into:

```
_invoke_esbmc(input_path, language, flags, unwind, timeout) -> raw_result
_normalise_esbmc_result(raw_result) -> Dict
```

Both `run_esbmc` (C) and `run_esbmc_python` (Python) call the same helper
with `language="c"` or `language="python"`. The flag-mapping table and the
retry logic (unwind escalation, timeout halving) move into this helper. This
collapses ~150 lines of duplicated logic that would otherwise appear in the
new path.

### 3.4 Cross-validation mode

A new orchestrator tool `cross_validate_backends` that:
1. Runs `run_esbmc_python` and `convert_python_to_c` + `run_esbmc` in
   parallel (subprocess level, no extra LLM calls).
2. Compares verdicts. Three outcomes:
   - **Agree → SUCCESSFUL or VIOLATION**: high-confidence verdict.
   - **Disagree → C path finds bug, Python path does not**: likely
     translation artefact; flag as "potential spurious — investigate".
   - **Disagree → Python path finds bug, C path does not**: likely C
     translation under-instrumented; flag as "translation gap".
3. If a counterexample exists, replay it against the Python interpreter
   (reusing the existing dynamic-execution tool) before reporting.

This is opt-in (`--cross-validate` CLI flag, or a tool the orchestrator can
invoke on its own when the LLM is uncertain). It directly addresses the
spurious-fault concern raised in §3.2 of the paper.

## 4. Implementation steps

Ordered, each step independently committable on a feature branch
`feat/eva-esbmc-python`. Steps 1–4 are the minimum viable integration;
5–7 are the cross-validation and benchmark work.

1. **Capability probe.** Extend `_analyze_ast`
   (`enhanced_verification_agent.py:1493`) to return
   `likely_esbmc_python_compatible: bool` and
   `python_features_unsupported: list[str]`. Use a deny-list of node types
   (e.g. `ast.AsyncFunctionDef`, `ast.Yield`, `ast.GeneratorExp` outside
   list-comprehension shape, `ast.Try` with non-trivial handlers). The
   deny-list is calibrated against the upstream ESBMC-Python test suite —
   list it in a constants module so it can be updated when ESBMC-Python
   gains features.

2. **Shared invoker.** Extract `_invoke_esbmc` and `_normalise_esbmc_result`
   from `_run_esbmc_attempt` (~line 1102). Cover with unit tests that mock
   `subprocess.run`.

3. **`run_esbmc_python` tool.** Add the tool entry to `self.tools`, wire
   `_execute_tool` (~line 496) to dispatch, implement `_run_esbmc_python`
   on top of `_invoke_esbmc` with `--python` (or whatever flag the local
   ESBMC build exposes — confirm with `esbmc --help | grep -i python`
   during install).

4. **Orchestrator prompt update.** Edit the initial-message template in
   `verify` (~line 225) to include the §3.2 selection rule. Keep the
   existing rules intact — the new one slots in just before the ESBMC
   guidance block.

5. **Cross-validate tool.** Implement `cross_validate_backends` as a
   non-LLM tool that internally calls the two `_run_esbmc*` paths via
   `concurrent.futures.ThreadPoolExecutor` (subprocess-bound, so threads
   suffice). Wire into the prompt as "use when verdicts feel inconsistent
   or for safety-critical assertions".

6. **Regression benchmark extension.** The paper's 23-program benchmark
   lives at `agent/benchmark/` (paper §4). Re-run it three ways: path A
   only (today's behaviour), path B only (new), and orchestrated. Record
   per-program: verdict, wall-clock, LLM tokens, ESBMC time. Expected
   outcome: path B wins on simple-arithmetic programs (no translation
   round-trip), path A still needed for the class-based and
   comprehension-heavy ones. Capture this as the empirical contribution
   for a follow-up paper.

7. **ESBMC-Python-native cases.** Pull a handful of programs from
   ESBMC's `regression/python/` suite (Ethereum Consensus subset) and add
   them as a separate benchmark group, so the new path is exercised on
   programs the original benchmark did not cover.

## 5. Risks and mitigations

| Risk | Mitigation |
|---|---|
| ESBMC-Python rejects a construct mid-verification with a non-structured error | Capture stderr verbatim; classify via regex into `unsupported_construct` vs `crash`; fall back to path A. |
| Two backends disagree silently and the LLM picks the wrong one | Cross-validation mode (§3.4) + Python-interpreter replay of any counterexample, same trick the paper already uses to dismiss spurious C-path faults. |
| Orchestrator becomes confused with too many similar tools | Group them in the prompt under a clear "formal verification" header and rely on `analyze_ast`'s structured hint to pre-commit a backend before the ESBMC step. |
| Existing 23-program benchmark masks regressions because it was designed against path A | Step 7 — add ESBMC-Python-native programs. Also report results on SV-COMP Python subset (paper §6 future work) once available. |
| The `--python` flag name differs between locally-installed ESBMC and upstream HEAD | Wrap the flag in a config constant; detect via `esbmc --help` at agent startup; surface a clear error if the running ESBMC has no Python front-end. |

## 6. Success criteria

1. `run_esbmc_python` integrated, dispatched by the orchestrator without
   manual flagging, and passes the existing 23-program benchmark with
   detection-rate ≥ today's (no regression).
2. On the arithmetic + bounds subset (18 programs), median wall-clock and
   LLM token count both drop measurably compared to path A — this is the
   intended speedup from skipping translation.
3. Cross-validation mode produces zero false agreements on the planted-bug
   set (i.e. when both backends say SUCCESSFUL, no bug is missed).
4. The ESBMC-Python-native benchmark group (step 7) is verified end-to-end
   without invoking the LLM-translation path.

## 7. Open questions for the user

- Should ESBMC-Python be the **default** formal-verification backend, with
  path A as fallback, or stay opt-in until step-6 numbers are in? My read:
  default after step 6 lands; opt-in until then.
- Is there appetite to publish the comparative-benchmark result as a short
  follow-up (workshop / tool paper), or fold it into a journal version of
  the AISOLA paper?
- Do you want the cross-validation mode wired to a CLI flag, an orchestrator
  decision, or both?

---

*Plan only — no code written. Implementation starts on a `feat/eva-esbmc-python` branch once the open questions are resolved.*
