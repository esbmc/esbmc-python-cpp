"""
Tests for esbmc_python_backend.

Covers the three pure-Python pieces — capability probe, ESBMC-output
classification, and verdict reconciliation — without mocks. The integration
test for invoke_esbmc is skipped when ESBMC is not on PATH or at
$ESBMC_PATH.
"""

import ast
import os
import shutil
import sys
import textwrap
import unittest

sys.path.insert(0, os.path.dirname(__file__))

from esbmc_python_backend import (  # noqa: E402
    classify_esbmc_output,
    invoke_esbmc,
    probe_python_compatibility,
    reconcile_verdicts,
)


def _esbmc_binary():
    """Locate an ESBMC binary; return None if not available."""
    candidate = os.environ.get("ESBMC_PATH") or shutil.which("esbmc")
    if candidate and os.path.exists(candidate) and os.access(candidate, os.X_OK):
        return candidate
    return None


class ProbePythonCompatibilityTests(unittest.TestCase):
    """probe_python_compatibility's deny-list."""

    def _probe(self, src):
        return probe_python_compatibility(ast.parse(textwrap.dedent(src)))

    def test_plain_arithmetic_is_compatible(self):
        result = self._probe("""
            def main():
                x = 1
                y = 2
                assert x + y == 3
        """)
        self.assertTrue(result["compatible"])
        self.assertEqual(result["unsupported_features"], [])

    def test_async_function_flagged(self):
        result = self._probe("""
            async def main():
                return 1
        """)
        self.assertFalse(result["compatible"])
        self.assertIn("AsyncFunctionDef", result["unsupported_features"])

    def test_yield_flagged(self):
        result = self._probe("""
            def gen():
                yield 1
        """)
        self.assertFalse(result["compatible"])
        self.assertIn("Yield", result["unsupported_features"])

    def test_lambda_flagged(self):
        result = self._probe("f = lambda x: x + 1")
        self.assertFalse(result["compatible"])
        self.assertIn("Lambda", result["unsupported_features"])

    def test_generator_expression_flagged(self):
        result = self._probe("xs = list(i for i in range(3))")
        self.assertFalse(result["compatible"])
        self.assertIn("GeneratorExp", result["unsupported_features"])

    def test_match_statement_flagged(self):
        # ast.Match exists from Python 3.10+
        if not hasattr(ast, "Match"):
            self.skipTest("ast.Match not available")
        result = self._probe("""
            def f(x):
                match x:
                    case 1:
                        return 1
                    case _:
                        return 0
        """)
        self.assertFalse(result["compatible"])
        self.assertIn("Match", result["unsupported_features"])

    def test_safe_decorator_not_flagged(self):
        result = self._probe("""
            from dataclasses import dataclass

            @dataclass
            class Point:
                x: int
                y: int
        """)
        self.assertTrue(result["compatible"])

    def test_unknown_decorator_flagged(self):
        result = self._probe("""
            @my_custom_decorator
            def f():
                return 1
        """)
        self.assertFalse(result["compatible"])
        self.assertIn("decorator:@my_custom_decorator", result["unsupported_features"])

    def test_decorator_call_form_uses_underlying_name(self):
        result = self._probe("""
            @some.module.decorator()
            def f():
                return 1
        """)
        self.assertFalse(result["compatible"])
        self.assertIn("decorator:@decorator", result["unsupported_features"])

    def test_deduplication_of_repeated_features(self):
        result = self._probe("""
            def g():
                yield 1
                yield 2
                yield 3
        """)
        self.assertEqual(result["unsupported_features"].count("Yield"), 1)


class ClassifyEsbmcOutputTests(unittest.TestCase):
    """classify_esbmc_output verdict mapping."""

    def test_successful_verification(self):
        r = classify_esbmc_output("...\nVERIFICATION SUCCESSFUL\n", 0)
        self.assertEqual(r["verdict"], "VERIFIED")
        self.assertFalse(r["unsupported_construct"])
        self.assertFalse(r["timed_out"])

    def test_failed_verification(self):
        r = classify_esbmc_output("...\nVERIFICATION FAILED\n", 0)
        self.assertEqual(r["verdict"], "VIOLATION")

    def test_unsupported_overrides_success(self):
        # If ESBMC prints the banner but then prints an unsupported-construct
        # error, treat as INCONCLUSIVE — the banner is unreliable on its own.
        r = classify_esbmc_output(
            "VERIFICATION SUCCESSFUL\nERROR: Unsupported AST node Yield\n", 0)
        self.assertEqual(r["verdict"], "INCONCLUSIVE")
        self.assertTrue(r["unsupported_construct"])

    def test_unsupported_does_not_mask_violation(self):
        # A real violation always wins — silent unsupported messages shouldn't
        # downgrade a counterexample.
        r = classify_esbmc_output(
            "ERROR: Unsupported AST node Yield\nVERIFICATION FAILED\n", 0)
        self.assertEqual(r["verdict"], "VIOLATION")
        self.assertTrue(r["unsupported_construct"])

    def test_undefined_function_is_not_treated_as_unsupported(self):
        # 'undefined function' fires for legitimate C harnesses that link
        # against externs; never let it downgrade a real verdict.
        r = classify_esbmc_output(
            "WARNING: Undefined function 'foo'\nVERIFICATION SUCCESSFUL\n", 0)
        self.assertEqual(r["verdict"], "VERIFIED")
        self.assertFalse(r["unsupported_construct"])

    def test_cannot_open_file_is_unsupported(self):
        r = classify_esbmc_output(
            "ERROR: Cannot open file: /tmp/x.json\n", 0)
        self.assertEqual(r["verdict"], "INCONCLUSIVE")
        self.assertTrue(r["unsupported_construct"])

    def test_timeout(self):
        r = classify_esbmc_output("⏱️  ESBMC timeout - process killed\n", -1)
        self.assertEqual(r["verdict"], "INCONCLUSIVE")
        self.assertTrue(r["timed_out"])

    def test_empty_output(self):
        r = classify_esbmc_output("", 0)
        self.assertEqual(r["verdict"], "INCONCLUSIVE")


class ReconcileVerdictsTests(unittest.TestCase):
    """reconcile_verdicts enforces ESBMC-Python authority."""

    @staticmethod
    def _v(verdict, **extra):
        return {"verdict": verdict, **extra}

    def test_direct_verified_is_authoritative(self):
        r = reconcile_verdicts(self._v("VERIFIED"), None)
        self.assertEqual(r["verdict"], "VERIFIED")
        self.assertEqual(r["authority"], "esbmc-python")

    def test_direct_violation_is_authoritative(self):
        r = reconcile_verdicts(self._v("VIOLATION"), self._v("VERIFIED"))
        self.assertEqual(r["verdict"], "VIOLATION")
        self.assertEqual(r["authority"], "esbmc-python")
        # Notes should flag the translation disagreement.
        self.assertTrue(any("sound backend" in n for n in r["notes"]))

    def test_translation_violation_suppressed_when_direct_clears(self):
        r = reconcile_verdicts(self._v("VERIFIED"), self._v("VIOLATION"))
        self.assertEqual(r["verdict"], "VERIFIED")
        self.assertTrue(any("artefact" in n for n in r["notes"]))

    def test_translation_cannot_clear_when_direct_unsupported(self):
        r = reconcile_verdicts(
            self._v("INCONCLUSIVE", unsupported_construct=True),
            self._v("VERIFIED"),
        )
        self.assertEqual(r["verdict"], "INCONCLUSIVE")
        self.assertEqual(r["authority"], "none")
        # The user should see why the program isn't cleared.
        self.assertTrue(any("not proven semantically equivalent" in n for n in r["notes"]))

    def test_translation_violation_when_direct_unsupported_is_suspicion(self):
        r = reconcile_verdicts(
            self._v("INCONCLUSIVE", unsupported_construct=True),
            self._v("VIOLATION"),
        )
        self.assertEqual(r["verdict"], "INCONCLUSIVE")
        self.assertEqual(r["authority"], "translation-suspect")
        self.assertTrue(any("best-effort" in n for n in r["notes"]))

    def test_translation_alone_can_only_suspect(self):
        r = reconcile_verdicts(None, self._v("VIOLATION"))
        self.assertEqual(r["verdict"], "INCONCLUSIVE")
        self.assertEqual(r["authority"], "translation-suspect")

    def test_translation_verified_alone_does_not_clear(self):
        r = reconcile_verdicts(None, self._v("VERIFIED"))
        self.assertEqual(r["verdict"], "INCONCLUSIVE")
        self.assertEqual(r["authority"], "none")

    def test_no_backend_run(self):
        r = reconcile_verdicts(None, None)
        self.assertEqual(r["verdict"], "INCONCLUSIVE")
        self.assertEqual(r["authority"], "none")
        self.assertTrue(any("No formal-verification backend was run" in n for n in r["notes"]))

    def test_both_inconclusive(self):
        r = reconcile_verdicts(self._v("INCONCLUSIVE"), self._v("INCONCLUSIVE"))
        self.assertEqual(r["verdict"], "INCONCLUSIVE")
        self.assertEqual(r["authority"], "none")


class InvokeEsbmcIntegrationTests(unittest.TestCase):
    """End-to-end checks that exercise ESBMC itself. Skipped if no binary."""

    esbmc: str

    @classmethod
    def setUpClass(cls):
        path = _esbmc_binary()
        if not path:
            raise unittest.SkipTest("ESBMC not found on PATH or at $ESBMC_PATH")
        cls.esbmc = path

    def _write(self, name, src):
        path = os.path.join("/tmp", name)
        with open(path, "w") as f:
            f.write(textwrap.dedent(src))
        self.addCleanup(lambda: os.path.exists(path) and os.remove(path))
        return path

    def test_python_verified(self):
        path = self._write("eva_test_ok.py", """
            def main():
                x = 1
                y = 2
                assert x + y == 3
            main()
        """)
        result = invoke_esbmc(
            path, esbmc_path=self.esbmc,
            unwind=5, timeout=15, enable_flags=[],
        )
        self.assertEqual(result["verdict"], "VERIFIED")
        self.assertTrue(result["success"])

    def test_python_violation(self):
        path = self._write("eva_test_bug.py", """
            def main():
                x = 1
                y = 2
                assert x + y == 99
            main()
        """)
        result = invoke_esbmc(
            path, esbmc_path=self.esbmc,
            unwind=5, timeout=15, enable_flags=[],
        )
        self.assertEqual(result["verdict"], "VIOLATION")
        self.assertFalse(result["success"])

    def test_python_unsupported_construct(self):
        path = self._write("eva_test_gen.py", """
            def gen():
                yield 1
            def main():
                g = gen()
                assert next(g) == 1
            main()
        """)
        result = invoke_esbmc(
            path, esbmc_path=self.esbmc,
            unwind=5, timeout=15, enable_flags=[],
        )
        # Either INCONCLUSIVE with unsupported_construct, or VIOLATION if
        # ESBMC lowers the unsupported function call to assert(false).
        self.assertIn(result["verdict"], {"INCONCLUSIVE", "VIOLATION"})

    def test_unknown_flag_is_stripped_and_retried(self):
        # Pass a bogus flag the running ESBMC build cannot recognise; the
        # helper should strip it and recover.
        path = self._write("eva_test_retry.py", """
            def main():
                assert 1 + 1 == 2
            main()
        """)
        result = invoke_esbmc(
            path, esbmc_path=self.esbmc,
            unwind=5, timeout=15,
            enable_flags=["--definitely-not-a-real-esbmc-flag"],
        )
        self.assertEqual(result["verdict"], "VERIFIED")


if __name__ == "__main__":
    unittest.main()
