"""
ESBMC-Python backend support: capability probing, ESBMC invocation, and
sound verdict reconciliation between the direct-Python and translation paths.

This module is import-side-effect free and free of the LLM client, so its
pure-Python pieces (capability probe, verdict reconciliation, ESBMC-output
classification) are unit-testable without subprocess or network.
"""

import ast
import os
import re
import subprocess
import time
from typing import Dict, List, Optional, Tuple


# Python AST nodes ESBMC-Python's front-end is known not to handle.
# Calibrated against ESBMC 8.x behaviour observed locally. When ESBMC-Python
# gains coverage upstream, prune entries here.
PYTHON_UNSUPPORTED_NODES: Tuple[type, ...] = (
    ast.AsyncFunctionDef,
    ast.AsyncFor,
    ast.AsyncWith,
    ast.Await,
    ast.Yield,
    ast.YieldFrom,
    ast.GeneratorExp,
    ast.Match,
    ast.Lambda,
)

# Decorators known to be safe; anything else is treated as a coverage risk.
PYTHON_SAFE_DECORATORS = frozenset({
    "dataclass",
    "frozen_dataclass",
    "staticmethod",
    "classmethod",
    "property",
})

# ESBMC stderr/stdout fragments that mean "I cannot lower this Python".
# Matched case-insensitively. Used by classify_esbmc_output().
# Scoped tightly to Python-frontend phrasings; we deliberately do not match
# generic "undefined function" because that fires on legitimate C harnesses
# whose externs are intentionally unresolved.
UNSUPPORTED_PATTERNS: Tuple[str, ...] = (
    "unsupported ast node",
    "unsupported comparison",
    "unsupported operand",
    "unable to handle",
    "cannot open file:",
    "not yet supported",
)


def _decorator_name(dec: ast.expr) -> str:
    """Return the bare name of a decorator AST node, or '' if not a Name/Attr."""
    if isinstance(dec, ast.Name):
        return dec.id
    if isinstance(dec, ast.Call):
        return _decorator_name(dec.func)
    if isinstance(dec, ast.Attribute):
        return dec.attr
    return ""


def probe_python_compatibility(tree: ast.AST) -> Dict:
    """Probe whether a parsed Python AST is likely to be accepted by ESBMC-Python.

    Returns a dict with:
      - compatible: bool — True iff no banned construct was found.
      - unsupported_features: list[str] — human-readable names of constructs
        that triggered the deny-list (deduplicated, in source order).

    This is a static, conservative pre-check; the authoritative answer is
    whatever ESBMC-Python itself reports when invoked on the file.
    """
    unsupported: List[str] = []
    seen = set()

    def report(name: str) -> None:
        if name not in seen:
            seen.add(name)
            unsupported.append(name)

    for node in ast.walk(tree):
        if isinstance(node, PYTHON_UNSUPPORTED_NODES):
            report(type(node).__name__)
        decorators = getattr(node, "decorator_list", None)
        if decorators:
            for dec in decorators:
                name = _decorator_name(dec)
                if name and name not in PYTHON_SAFE_DECORATORS:
                    report(f"decorator:@{name}")

    return {"compatible": not unsupported, "unsupported_features": unsupported}


def classify_esbmc_output(output: str, return_code: int) -> Dict:
    """Classify an ESBMC run by its terminal output.

    Returns a dict with:
      - verdict: 'VERIFIED' | 'VIOLATION' | 'INCONCLUSIVE'
      - unsupported_construct: bool — True if ESBMC reported a feature it
        cannot lower (Python-frontend specific in practice).
      - timed_out: bool

    ESBMC exits with rc=0 even on VERIFICATION FAILED, so verdict is derived
    from output text, never from the return code.
    """
    text = output or ""
    lower = text.lower()

    timed_out = "timeout" in lower and "process killed" in lower

    unsupported = any(pat in lower for pat in UNSUPPORTED_PATTERNS)

    if "VERIFICATION SUCCESSFUL" in text:
        verdict = "VERIFIED"
    elif "VERIFICATION FAILED" in text:
        verdict = "VIOLATION"
    else:
        verdict = "INCONCLUSIVE"

    # An unsupported-construct error overrides a stale SUCCESSFUL banner, since
    # ESBMC may still print version info after a parse failure.
    if unsupported and verdict != "VIOLATION":
        verdict = "INCONCLUSIVE"

    return {
        "verdict": verdict,
        "unsupported_construct": unsupported,
        "timed_out": timed_out,
        "return_code": return_code,
    }


def latest_esbmc_result(all_tool_results: Dict, tool_key: str) -> Optional[Dict]:
    """Return the most recent result for tool_key in all_tool_results, or None."""
    history = all_tool_results.get(tool_key)
    return history[-1] if history else None


def build_verify_result(iterations: int, all_tool_results: Dict,
                        conversion_artifacts: Dict, final_text: str) -> Dict:
    """Compose the agent's verify() return dict with a reconciled verdict.

    The 'verdict' field is computed from raw ESBMC outputs via
    reconcile_verdicts() and is authoritative. The LLM narration in
    final_verdict is purely explanatory and never sets the verdict.
    """
    # Keys here MUST match the tool names registered with the Anthropic API
    # (see EnhancedVerificationAgent.tools); all_tool_results is keyed by
    # tool_use.name, not by the result dict's internal "tool" field.
    reconciled = reconcile_verdicts(
        latest_esbmc_result(all_tool_results, "run_esbmc_python"),
        latest_esbmc_result(all_tool_results, "run_esbmc"),
    )
    return {
        "iterations": iterations,
        "tools_used": list(all_tool_results.keys()),
        "tool_results": all_tool_results,
        "conversion_artifacts": conversion_artifacts,
        "final_verdict": final_text,
        "verdict": reconciled["verdict"],
        "verdict_authority": reconciled["authority"],
        "verdict_notes": reconciled["notes"],
        "verified": reconciled["verdict"] == "VERIFIED",
    }


def reconcile_verdicts(direct: Optional[Dict], translation: Optional[Dict]) -> Dict:
    """Reconcile the two ESBMC paths into a single, sound user-facing verdict.

    Inputs are either None (path was not run) or a dict containing at least a
    'verdict' key from classify_esbmc_output(). 'direct' is ESBMC-Python's
    result (sound on supported fragments); 'translation' is ESBMC on
    LLM-translated C (heuristic — semantic equivalence is not proven).

    The pipeline is non-bypassable and follows the project's no-mistakes rule:
      - ESBMC-Python's VERIFIED or VIOLATION is authoritative.
      - The translation path can only raise SUSPECTED violations; it cannot
        clear a program ESBMC-Python found buggy, nor mark VERIFIED on its
        own.

    Returns: {verdict, authority, notes: list[str]}.
    """
    notes: List[str] = []
    d = (direct or {}).get("verdict")
    t = (translation or {}).get("verdict")

    if d == "VERIFIED":
        if t == "VIOLATION":
            notes.append(
                "Translation path reported a violation; suppressed as a "
                "translation artefact because ESBMC-Python (sound on this "
                "fragment) proved the property."
            )
        return {"verdict": "VERIFIED", "authority": "esbmc-python", "notes": notes}

    if d == "VIOLATION":
        if t == "VERIFIED":
            notes.append(
                "Translation path reported VERIFIED but ESBMC-Python found a "
                "violation; the sound backend takes precedence."
            )
        return {"verdict": "VIOLATION", "authority": "esbmc-python", "notes": notes}

    # ESBMC-Python is INCONCLUSIVE or was not run. Translation path cannot
    # produce an authoritative VERIFIED.
    if direct is not None and (direct or {}).get("unsupported_construct"):
        notes.append("ESBMC-Python could not lower one or more Python constructs.")

    if t == "VIOLATION":
        notes.append(
            "Translation path reports a suspected violation. This is "
            "best-effort: the Python-to-C translation is not proven "
            "semantically equivalent, so this finding requires confirmation "
            "by interpreter replay or by ESBMC-Python on a reduced witness."
        )
        return {
            "verdict": "INCONCLUSIVE",
            "authority": "translation-suspect",
            "notes": notes,
        }

    if t == "VERIFIED":
        notes.append(
            "Translation path reports VERIFIED but cannot clear the program "
            "because Python-to-C translation is not proven semantically "
            "equivalent."
        )

    if direct is None and translation is None:
        notes.append("No formal-verification backend was run.")

    return {"verdict": "INCONCLUSIVE", "authority": "none", "notes": notes}


def _stream_subprocess(cmd: List[str], timeout: int) -> Tuple[str, int]:
    """Run cmd, streaming combined stdout/stderr to console, returning (output, rc).

    Kills the process if it exceeds timeout+10 seconds wall-clock.
    Mirrors the streaming UX used elsewhere in the agent.
    """
    process = subprocess.Popen(
        cmd,
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        text=True,
        bufsize=1,
        universal_newlines=True,
    )

    output_lines: List[str] = []
    start = time.time()
    killed = False
    try:
        assert process.stdout is not None  # subprocess.PIPE guarantees this
        for line in process.stdout:
            print(f"         {line}", end="")
            output_lines.append(line)
            if time.time() - start > timeout + 10:
                process.kill()
                killed = True
                output_lines.append("\n⏱️  ESBMC timeout - process killed\n")
                break
        process.wait(timeout=5)
        rc = process.returncode
    except (OSError, subprocess.SubprocessError) as e:
        process.kill()
        killed = True
        output_lines.append(f"\n❌ Error during streaming: {e}\n")
        rc = -1
    finally:
        # Reap the child after kill so it does not linger as a zombie, and
        # close the stdout pipe to release the fd promptly.
        if killed:
            try:
                process.wait(timeout=5)
            except subprocess.TimeoutExpired:
                pass
        if process.stdout is not None:
            process.stdout.close()
    return "".join(output_lines), rc


def _retry_without_bad_option(output: str, cmd: List[str]) -> Optional[List[str]]:
    """If ESBMC complained about an unrecognised option, return cmd without it."""
    match = re.search(r"unrecognised option '([^']+)'", output)
    if not match:
        return None
    bad = match.group(1)
    if not bad.startswith("--"):
        bad = "--" + bad
    fixed = [arg for arg in cmd if arg != bad]
    return fixed if fixed != cmd else None


def invoke_esbmc(
    filename: str,
    *,
    esbmc_path: str,
    unwind: int,
    timeout: int,
    enable_flags: List[str],
    disable_flags: Optional[List[str]] = None,
) -> Dict:
    """Invoke ESBMC on filename and return a normalised result.

    filename: path to either .c or .py source — ESBMC selects its front-end
    from the extension; this helper is language-agnostic on purpose.

    enable_flags / disable_flags: explicit list of ESBMC switches to add to the
    command line. Caller is responsible for choosing semantically correct flags
    for the target language.

    Returns a dict with the same shape used elsewhere in the agent:
      tool, success, output, return_code, enabled_checks, saved_file, command,
      verdict, unsupported_construct, timed_out.
    """
    cmd = [esbmc_path, filename, "--unwind", str(unwind), "--timeout", str(timeout)]
    cmd.extend(enable_flags)
    if disable_flags:
        cmd.extend(disable_flags)

    print(f"      🚀 Running: {' '.join(cmd)}")
    print("      📡 Streaming output:\n")

    output, rc = _stream_subprocess(cmd, timeout)

    fixed = _retry_without_bad_option(output, cmd)
    if fixed is not None:
        print(f"\n      🔧 Removed unrecognised option; retrying with: {' '.join(fixed)}\n")
        output, rc = _stream_subprocess(fixed, timeout)
        cmd = fixed

    classification = classify_esbmc_output(output, rc)

    inspection = (
        f"\n📝 Input file: {os.path.abspath(filename)}"
        f"\n💡 Command: {' '.join(cmd)}"
    )

    return {
        "tool": "esbmc",
        "success": classification["verdict"] == "VERIFIED",
        "output": output + inspection,
        "return_code": rc,
        "enabled_checks": [f.lstrip("-") for f in enable_flags],
        "saved_file": filename,
        "command": " ".join(cmd),
        "verdict": classification["verdict"],
        "unsupported_construct": classification["unsupported_construct"],
        "timed_out": classification["timed_out"],
    }
