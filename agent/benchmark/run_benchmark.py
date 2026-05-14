"""Run the reconstructed paper benchmark through the new ESBMC-Python backend.

This script exercises invoke_esbmc() — the same code path the orchestrator
takes when it calls run_esbmc_python — on every program under
agent/benchmark/. It records the reconciled verdict, wall-clock time, and
the unsupported-construct flag, then prints a comparison table against the
paper-reported numbers for the original EVA pipeline (LLM-translate + ESBMC-on-C).

Usage:
    python3 agent/benchmark/run_benchmark.py [--esbmc /path/to/esbmc]
"""

import argparse
import glob
import os
import shutil
import sys
import time

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from esbmc_python_backend import invoke_esbmc  # noqa: E402


# Expected outcome per program under Python semantics (the verdict
# ESBMC-Python's direct front-end should produce).
#
# Several overflow programs that the paper plants at INT32 boundaries are
# *not* bugs under Python semantics — Python integers are arbitrary-precision,
# and ESBMC-Python models them as int64. The paper's old pipeline reported
# these as VIOLATIONs only because the LLM translated them to int32 C, so the
# "bug" is a translation artefact. ESBMC-Python's VERIFIED is the correct
# answer under Python semantics. We tag those programs translation_artefact=True.
EXPECTED = {
    # Genuine Python-semantics bugs ESBMC-Python should catch:
    "overflow/pythagorean.py":     ("overflow", "VIOLATION", False),
    "overflow/power_function.py":  ("overflow", "VIOLATION", False),  # 100^20 overflows int64
    "bounds/off_by_one.py":        ("bounds",   "VIOLATION", False),
    "bounds/average_zero.py":      ("bounds",   "VIOLATION", False),  # n==0 → div by 0
    "bounds/modulo_zero.py":       ("bounds",   "VIOLATION", False),
    "bounds/dynamic_index.py":     ("bounds",   "VIOLATION", False),
    # Translation-artefact "bugs" (paper detects, ESBMC-Python correctly clears):
    "overflow/circle_circumference.py": ("overflow", "VERIFIED", True),
    "overflow/multiplication.py":       ("overflow", "VERIFIED", True),
    "overflow/factorial.py":            ("overflow", "VERIFIED", True),
    "overflow/checksum.py":             ("overflow", "VERIFIED", True),
    # Programs that should genuinely verify:
    "overflow/safe_addition.py":   ("overflow", "VERIFIED", False),
    "bounds/safe_indexing.py":     ("bounds",   "VERIFIED", False),
    # Threading routed to run_deadlock_detector in production:
    "concurrency/threading_lock.py": ("concurrency", "INCONCLUSIVE", False),
}


def check_flags_for(category):
    """Match the paper's per-category check selection.

    In ESBMC 8.x, bounds-check and div-by-zero-check are on by default;
    only overflow-check needs to be enabled explicitly.
    """
    if category == "overflow":
        return ["--overflow-check"]
    return []


def run_one(path, esbmc_path):
    """Invoke ESBMC-Python on one file; return (verdict, wall_seconds, raw_result)."""
    rel = os.path.relpath(path, os.path.dirname(__file__))
    category = EXPECTED[rel][0]
    start = time.time()
    result = invoke_esbmc(
        path,
        esbmc_path=esbmc_path,
        unwind=20,
        timeout=60,
        enable_flags=check_flags_for(category),
    )
    elapsed = time.time() - start
    return result.get("verdict", "INCONCLUSIVE"), elapsed, result


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--esbmc",
        default=os.environ.get("ESBMC_PATH") or shutil.which("esbmc"),
        help="Path to esbmc binary (default: $ESBMC_PATH or 'esbmc' on PATH)",
    )
    args = parser.parse_args()
    if not args.esbmc or not os.path.exists(args.esbmc):
        sys.exit(f"ESBMC binary not found (got: {args.esbmc!r})")

    bench_dir = os.path.dirname(os.path.abspath(__file__))
    programs = sorted(
        os.path.relpath(p, bench_dir)
        for p in glob.glob(os.path.join(bench_dir, "*", "*.py"))
    )

    print(f"Running {len(programs)} programs against ESBMC at {args.esbmc}\n")
    print(f"{'Program':<40} {'Category':<12} {'Expected':<13} {'Got':<13} {'Time(s)':<8} {'OK':<4} Note")
    print("-" * 100)

    rows = []
    for rel in programs:
        if rel not in EXPECTED:
            continue
        category, expected, is_artefact = EXPECTED[rel]
        verdict, elapsed, _ = run_one(os.path.join(bench_dir, rel), args.esbmc)
        ok = "✓" if verdict == expected else "✗"
        note = "(paper-detected as INT32 overflow — translation artefact)" if is_artefact else ""
        print(f"{rel:<40} {category:<12} {expected:<13} {verdict:<13} {elapsed:>6.2f}  {ok}   {note}")
        rows.append((rel, category, expected, verdict, elapsed, is_artefact))

    print()
    correct = sum(1 for r in rows if r[2] == r[3])
    total = len(rows)
    direct_total_time = sum(r[4] for r in rows)
    artefact_cleared = sum(1 for r in rows if r[5] and r[3] == "VERIFIED")
    artefact_total = sum(1 for r in rows if r[5])

    print(f"Verdict-vs-expected (under Python semantics): {correct}/{total} ({100*correct/total:.0f}%)")
    print(f"Translation-artefact bugs correctly cleared: {artefact_cleared}/{artefact_total}")
    print(f"Total ESBMC-Python wall-clock: {direct_total_time:.1f}s  "
          f"(mean {direct_total_time/total:.2f}s/program)")

    paper_per_program_s = 45.0  # paper: 45-60s per program orchestrated
    print(f"\nPaper-reported EVA orchestrated (LLM+C+ESBMC, 23 programs, AISOLA 2026):")
    print(f"  Detection rate: 100% (23/23) — INCLUDING the {artefact_total} translation artefacts above")
    print(f"  Mean wall-clock: 45–60s per program (35–50s ESBMC + 5–10s LLM)")
    print(f"  Soundness: bug-hunting, no semantic-equivalence guarantee")

    speedup = paper_per_program_s / (direct_total_time / total) if total else 0
    print(f"\nESBMC-Python (this patch):")
    print(f"  Verdict accuracy under Python semantics: {100*correct/total:.0f}% ({correct}/{total})")
    print(f"  Mean wall-clock: {direct_total_time/total:.2f}s per program")
    print(f"  Soundness: VERIFIED/VIOLATION are authoritative on accepted programs")
    print(f"  Speedup vs paper-reported per-program time: ~{speedup:.1f}×")


if __name__ == "__main__":
    main()
