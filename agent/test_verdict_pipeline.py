"""
Tests for the verdict-pipeline glue (latest_esbmc_result, build_verify_result)
that the agent uses to derive the user-facing verdict from raw tool outputs.
"""

import os
import sys
import unittest

sys.path.insert(0, os.path.dirname(__file__))

from esbmc_python_backend import (  # noqa: E402
    build_verify_result,
    latest_esbmc_result,
)

# Tool-name keys exactly as registered with the Anthropic API in
# EnhancedVerificationAgent.tools. Test against these directly so a rename or
# typo would fail the suite rather than silently degrade soundness.
TOOL_KEY_DIRECT = "run_esbmc_python"
TOOL_KEY_TRANSLATION = "run_esbmc"


class LatestEsbmcResultTests(unittest.TestCase):

    def test_missing_key_returns_none(self):
        self.assertIsNone(latest_esbmc_result({}, TOOL_KEY_DIRECT))

    def test_empty_history_returns_none(self):
        self.assertIsNone(
            latest_esbmc_result({TOOL_KEY_DIRECT: []}, TOOL_KEY_DIRECT))

    def test_returns_most_recent(self):
        history = {TOOL_KEY_DIRECT: [
            {"verdict": "INCONCLUSIVE"},
            {"verdict": "VERIFIED"},
        ]}
        self.assertEqual(
            latest_esbmc_result(history, TOOL_KEY_DIRECT),
            {"verdict": "VERIFIED"})


class BuildVerifyResultTests(unittest.TestCase):
    """The reconciled verdict — not LLM text — drives 'verified'."""

    def _build(self, tool_results):
        return build_verify_result(
            iterations=1,
            all_tool_results=tool_results,
            conversion_artifacts={},
            final_text="(claude says everything is fine, trust me)",
        )

    def test_direct_verified_wins(self):
        r = self._build({TOOL_KEY_DIRECT: [{"verdict": "VERIFIED"}]})
        self.assertEqual(r["verdict"], "VERIFIED")
        self.assertTrue(r["verified"])
        self.assertEqual(r["verdict_authority"], "esbmc-python")

    def test_translation_alone_cannot_verify_even_if_llm_says_so(self):
        # The LLM narration insists everything is fine; the verdict pipeline
        # must still refuse to clear because only the translation path ran.
        r = self._build({TOOL_KEY_TRANSLATION: [{"verdict": "VERIFIED"}]})
        self.assertEqual(r["verdict"], "INCONCLUSIVE")
        self.assertFalse(r["verified"])

    def test_direct_violation_overrides_translation_verified(self):
        r = self._build({
            TOOL_KEY_DIRECT: [{"verdict": "VIOLATION"}],
            TOOL_KEY_TRANSLATION: [{"verdict": "VERIFIED"}],
        })
        self.assertEqual(r["verdict"], "VIOLATION")
        self.assertEqual(r["verdict_authority"], "esbmc-python")

    def test_no_esbmc_run_is_inconclusive(self):
        r = self._build({"run_pylint": [{"output": "ok"}]})
        self.assertEqual(r["verdict"], "INCONCLUSIVE")
        self.assertEqual(r["verdict_authority"], "none")

    def test_lookup_uses_anthropic_tool_names(self):
        # Regression: build_verify_result must look up tool results under the
        # Claude-facing tool name (run_esbmc_python), not the internal "tool"
        # field of the result dict. A mismatch silently degrades soundness by
        # routing every direct-backend verdict to the translation-suspect
        # branch.
        #
        # We grep the agent source for the registered tool names (instead of
        # importing the agent, which would require the Anthropic SDK) so this
        # test fires the moment someone renames a tool without updating the
        # verdict-pipeline lookup keys.
        agent_src = os.path.join(
            os.path.dirname(__file__), "enhanced_verification_agent.py")
        with open(agent_src, encoding="utf-8") as f:
            source = f.read()
        self.assertIn(f'"name": "{TOOL_KEY_DIRECT}"', source)
        self.assertIn(f'"name": "{TOOL_KEY_TRANSLATION}"', source)

    def test_passes_through_iterations_and_artifacts(self):
        r = build_verify_result(
            iterations=7,
            all_tool_results={TOOL_KEY_DIRECT: [{"verdict": "VERIFIED"}]},
            conversion_artifacts={"c_code": "int main() { return 0; }"},
            final_text="narration",
        )
        self.assertEqual(r["iterations"], 7)
        self.assertEqual(r["conversion_artifacts"]["c_code"], "int main() { return 0; }")
        self.assertEqual(r["final_verdict"], "narration")
        self.assertIn(TOOL_KEY_DIRECT, r["tools_used"])


if __name__ == "__main__":
    unittest.main()
