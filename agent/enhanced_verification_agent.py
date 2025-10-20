"""
Enhanced Iterative Multi-Tool Verification Agent using Claude API
Requires all tools to be installed - see requirements.txt
"""

import anthropic
import subprocess
import tempfile
import os
import json
import ast
from typing import Dict, List, Optional


class EnhancedVerificationAgent:
    """
    Uses Claude's native tool use capability for comprehensive verification.
    All tools must be installed - this agent does not adapt to missing tools.
    """

    def __init__(self, api_key: str, force_tools: List[str] = None, esbmc_path: str = None):
        self.client = anthropic.Anthropic(api_key=api_key)
        self.model = "claude-sonnet-4-5-20250929"
        self.force_tools = force_tools or []

        # ESBMC executable path (default to 'esbmc' in PATH)
        self.esbmc_path = esbmc_path or os.environ.get('ESBMC_PATH', 'esbmc')

        # Verify required tools are installed
        self._check_prerequisites()

        # Define comprehensive verification tools
        self.tools = [
            {
                "name": "run_python_interpreter",
                "description": "Execute Python code and return stdout/stderr. Use this to test if code runs correctly.",
                "input_schema": {
                    "type": "object",
                    "properties": {
                        "code": {"type": "string", "description": "The Python code to execute"}
                    },
                    "required": ["code"]
                }
            },
            {
                "name": "run_mypy",
                "description": "Run mypy static type checker for Python. Use for type-annotated code to catch type errors.",
                "input_schema": {
                    "type": "object",
                    "properties": {
                        "code": {"type": "string", "description": "The Python code to type-check"}
                    },
                    "required": ["code"]
                }
            },
            {
                "name": "run_pylint",
                "description": "Run pylint for code quality analysis. Checks for errors, code smells, and style issues.",
                "input_schema": {
                    "type": "object",
                    "properties": {
                        "code": {"type": "string", "description": "The Python code to analyze"}
                    },
                    "required": ["code"]
                }
            },
            {
                "name": "run_bandit",
                "description": "Run bandit security scanner. Detects common security issues in Python code.",
                "input_schema": {
                    "type": "object",
                    "properties": {
                        "code": {"type": "string", "description": "The Python code to scan for security issues"}
                    },
                    "required": ["code"]
                }
            },
            {
                "name": "run_flake8",
                "description": "Run flake8 for style guide enforcement and error detection.",
                "input_schema": {
                    "type": "object",
                    "properties": {
                        "code": {"type": "string", "description": "The Python code to check"}
                    },
                    "required": ["code"]
                }
            },
            {
                "name": "convert_python_to_c",
                "description": "Convert Python code to C code for formal verification with ESBMC. Analyzes code to determine what verification checks are needed.",
                "input_schema": {
                    "type": "object",
                    "properties": {
                        "code": {"type": "string", "description": "The Python code to convert"},
                        "analysis": {"type": "object", "description": "Optional: AST analysis results to guide conversion", "default": {}}
                    },
                    "required": ["code"]
                }
            },
            {
                "name": "run_esbmc",
                "description": "Run ESBMC formal verification on C code. Automatically selects verification checks based on code analysis (overflow, bounds, division-by-zero, deadlocks).",
                "input_schema": {
                    "type": "object",
                    "properties": {
                        "code": {"type": "string", "description": "The C code to formally verify"},
                        "check_overflow": {"type": "boolean", "description": "Enable overflow checking", "default": False},
                        "check_bounds": {"type": "boolean", "description": "Enable array bounds checking", "default": False},
                        "check_div_by_zero": {"type": "boolean", "description": "Enable division by zero checking", "default": False},
                        "check_deadlock": {"type": "boolean", "description": "Enable deadlock checking for threading", "default": False},
                        "check_pointer": {"type": "boolean", "description": "Enable pointer safety checking", "default": False},
                        "check_memory_leak": {"type": "boolean", "description": "Enable memory leak detection", "default": False}
                    },
                    "required": ["code"]
                }
            },
            {
                "name": "analyze_ast",
                "description": "Parse Python code and analyze its AST to understand structure and detect patterns.",
                "input_schema": {
                    "type": "object",
                    "properties": {
                        "code": {"type": "string", "description": "The Python code to analyze"}
                    },
                    "required": ["code"]
                }
            },
            {
                "name": "run_deadlock_detector",
                "description": "Runtime deadlock detection for Python threading code. Instruments locks, detects circular dependencies, monitors thread states, and catches actual deadlocks. Much more reliable than C conversion for threading code.",
                "input_schema": {
                    "type": "object",
                    "properties": {
                        "code": {"type": "string", "description": "The Python code with threading to analyze"},
                        "timeout": {"type": "integer", "description": "Maximum execution time in seconds", "default": 5}
                    },
                    "required": ["code"]
                }
            }
        ]

    def _check_prerequisites(self):
        """Verify all required tools are installed"""
        required_commands = {
            'python3': 'Python 3',
            'mypy': 'mypy (pip install mypy)',
            'pylint': 'pylint (pip install pylint)',
            'bandit': 'bandit (pip install bandit)',
            'flake8': 'flake8 (pip install flake8)'
        }

        missing = []
        for cmd, desc in required_commands.items():
            try:
                subprocess.run([cmd, '--version'],
                             capture_output=True,
                             timeout=5,
                             check=False)
            except FileNotFoundError:
                missing.append(f"  - {desc}")

        if missing:
            print("⚠️  Warning: Some tools are not installed:")
            print("\n".join(missing))
            print("\nRun: pip install -r requirements.txt")

        # Check ESBMC if path is specified
        if self.esbmc_path != 'esbmc':
            print(f"\n🔍 Checking ESBMC at: {self.esbmc_path}")
            if not os.path.exists(self.esbmc_path):
                print(f"⚠️  Warning: ESBMC not found at {self.esbmc_path}")
            else:
                try:
                    result = subprocess.run([self.esbmc_path, '--version'],
                                          capture_output=True,
                                          timeout=5,
                                          check=False)
                    if result.returncode == 0:
                        version_output = result.stdout.decode('utf-8').split('\n')[0]
                        print(f"✓ Found: {version_output}")
                    else:
                        print(f"⚠️  ESBMC executable found but version check failed")
                except Exception as e:
                    print(f"⚠️  Warning: Could not verify ESBMC: {e}")
        else:
            print("\nNote: ESBMC requires separate installation (optional)")
            print("      Use --esbmc-path to specify custom location")

    def verify(self, code: str, max_iterations: int = 10) -> Dict:
        """
        Iteratively verify code using all available tools.
        Claude will use multiple tools to comprehensively verify the code.
        """

        print("="*80)
        print("COMPREHENSIVE VERIFICATION AGENT")
        print("="*80)
        print(f"\nCode to verify ({len(code)} chars)")
        print("-"*80)

        initial_message = f"""You are an expert code verification agent with access to multiple verification tools.
All tools are installed and available.

**Available Tools:**
- run_python_interpreter: Execute code to test functionality
- run_mypy: Static type checking (for type-annotated code)
- run_pylint: Code quality and error detection
- run_bandit: Security vulnerability scanning
- run_flake8: Style guide enforcement
- analyze_ast: Parse and analyze code structure (provides recommended ESBMC checks)
- run_deadlock_detector: **BEST TOOL FOR THREADING** - Runtime deadlock detection for Python threading code
  * Instruments locks to track acquisitions
  * Detects circular wait conditions (Thread A waits for B, B waits for A)
  * Detects inconsistent lock ordering across threads
  * Catches actual deadlocks via timeout
  * Much more reliable than ESBMC for threading code
  * Use this for ANY code with threading.Lock, threading.Thread, etc.
- convert_python_to_c: Convert Python to C for formal verification (can use AST analysis results)
- run_esbmc: Formal verification on C code with intelligent check selection
  * Available checks: overflow, bounds, div-by-zero, deadlock, pointer, memory-leak
  * Use AST analysis recommendations to select appropriate checks
  * Set specific check flags (check_overflow, check_bounds, etc.) based on code patterns
  * **NOT RECOMMENDED for threading code** - use run_deadlock_detector instead

**Your Strategy:**
1. Always start with analyze_ast to understand the code structure
   - AST analysis will provide recommended ESBMC checks
2. Use multiple complementary tools based on what you find:
   - If type annotations present: use mypy
   - Always use: pylint, flake8, bandit for comprehensive checking
   - Always try to execute: run_python_interpreter (unless it's clearly unsafe)
   - **If threading detected: ALWAYS use run_deadlock_detector** (much better than ESBMC for concurrency)
3. For formal verification with ESBMC (non-threading code only):
   - Convert to C using convert_python_to_c (pass AST analysis if available)
   - Run ESBMC with appropriate checks based on AST analysis recommendations:
     * check_overflow=true for arithmetic operations (add, multiply, subtract)
     * check_bounds=true for array/list access
     * check_div_by_zero=true for division operations
     * check_pointer=true for pointer operations
     * check_memory_leak=true for dynamic memory allocation
     * **Do NOT use check_deadlock=true** - use run_deadlock_detector instead
4. Use at least 4-6 different tools for thorough verification
5. Provide detailed analysis of each tool's findings

{'**REQUIRED TOOLS (must use):** ' + ', '.join(self.force_tools) if self.force_tools else ''}

**Code to verify:**
```python
{code}
```

Begin comprehensive verification. Start with AST analysis."""

        messages = [{"role": "user", "content": initial_message}]
        all_tool_results = {}
        conversion_artifacts = {}

        # Keep only last N iterations in full detail to prevent context overflow
        MAX_CONTEXT_ITERATIONS = 3
        message_checkpoint_indices = []

        for iteration in range(max_iterations):
            print(f"\n{'='*80}")
            print(f"ITERATION {iteration + 1}/{max_iterations}")
            print(f"{'='*80}\n")

            print(f"[{iteration + 1}.1] 🤖 Claude's Analysis:\n")

            # Truncate old messages if we have too many iterations
            if iteration > MAX_CONTEXT_ITERATIONS:
                # Keep: initial message + last MAX_CONTEXT_ITERATIONS iterations
                # Find where to cut
                messages_to_keep = 1  # Initial message
                recent_turns = MAX_CONTEXT_ITERATIONS * 2  # Each iteration = assistant + user message

                if len(messages) > messages_to_keep + recent_turns:
                    # Create summary of dropped iterations
                    dropped_count = (len(messages) - messages_to_keep - recent_turns) // 2
                    summary_msg = f"[Previous {dropped_count} iteration(s) summarized to save context]"

                    # Keep initial + recent messages
                    messages = [messages[0]] + [{
                        "role": "user",
                        "content": summary_msg
                    }] + messages[-(recent_turns):]

                    print(f"      ℹ️  Context management: Summarized {dropped_count} old iterations")

            # Use streaming for real-time output
            collected_content = []
            tool_uses = []

            with self.client.messages.stream(
                model=self.model,
                max_tokens=4000,
                tools=self.tools,
                messages=messages
            ) as stream:
                for event in stream:
                    if event.type == "content_block_start":
                        if event.content_block.type == "text":
                            pass  # Text block starting
                        elif event.content_block.type == "tool_use":
                            # Tool use block starting
                            pass

                    elif event.type == "content_block_delta":
                        if hasattr(event.delta, 'text'):
                            # Stream text in real-time
                            print(event.delta.text, end='', flush=True)

                    elif event.type == "content_block_stop":
                        pass  # Block finished

                # Get the final message
                response = stream.get_final_message()

            print("\n")  # New line after streaming text

            # Collect content blocks
            for block in response.content:
                collected_content.append(block)
                if block.type == "tool_use":
                    tool_uses.append(block)

            if not tool_uses:
                print("✅ Claude concluded verification (no more tools needed)")

                final_text = "\n".join([
                    block.text for block in response.content
                    if block.type == "text"
                ])

                return {
                    "iterations": iteration + 1,
                    "tools_used": list(all_tool_results.keys()),
                    "tool_results": all_tool_results,
                    "conversion_artifacts": conversion_artifacts,
                    "final_verdict": final_text,
                    "verified": self._determine_if_verified(final_text)
                }

            print(f"[{iteration + 1}.2] 🔧 Executing {len(tool_uses)} tool(s):")
            for tool_use in tool_uses:
                print(f"  - {tool_use.name}")

            messages.append({
                "role": "assistant",
                "content": collected_content
            })

            tool_results_content = []
            print(f"\n[{iteration + 1}.3] 🏃 Tool Results:\n")

            for tool_use in tool_uses:
                tool_name = tool_use.name
                tool_input = tool_use.input

                # Extract code and additional parameters
                tool_params = dict(tool_input)  # Make a copy
                code = tool_params.pop("code", "")

                result = self._execute_tool(tool_name, code, **tool_params)

                # Track tool results
                if tool_name not in all_tool_results:
                    all_tool_results[tool_name] = []
                all_tool_results[tool_name].append(result)

                # Store conversion artifacts
                if tool_name == "convert_python_to_c" and result.get('c_code'):
                    conversion_artifacts['c_code'] = result['c_code']

                status = "✅" if result.get('success') else "❌"
                print(f"  {status} {tool_name}:")

                # Show full output for failed tools, preview for successful ones
                output = result.get('output', '')
                if result.get('success'):
                    output_preview = output[:150].replace('\n', ' ')
                    print(f"      {output_preview}...")
                else:
                    # Show full error output for failed tools
                    print(f"      --- FULL OUTPUT ---")
                    print(output)
                    print(f"      --- END OUTPUT ---")

                tool_results_content.append({
                    "type": "tool_result",
                    "tool_use_id": tool_use.id,
                    "content": self._format_tool_result(result)
                })

            messages.append({
                "role": "user",
                "content": tool_results_content
            })

            if response.stop_reason == "end_turn":
                print("\n✅ Claude finished analysis")
                break

        # Get final comprehensive verdict with streaming
        print("\n" + "="*80)
        print("GENERATING FINAL VERDICT")
        print("="*80)
        print("\n🔍 Analyzing all tool results", end='', flush=True)

        # Show progress dots while waiting for first response
        import sys
        import threading
        import time

        stop_dots = threading.Event()
        def show_dots():
            while not stop_dots.is_set():
                print('.', end='', flush=True)
                time.sleep(0.5)

        dot_thread = threading.Thread(target=show_dots, daemon=True)
        dot_thread.start()

        messages_for_final = messages + [{
            "role": "user",
            "content": """Based on all the tool results, provide your final comprehensive verification verdict.

Include:
1. Summary of what was tested (which tools were used)
2. Key findings from each tool
3. Overall assessment (verified/not verified)
4. Any recommendations for improvement"""
        }]

        final_verdict_text = ""
        first_chunk = True
        with self.client.messages.stream(
            model=self.model,
            max_tokens=2000,
            messages=messages_for_final
        ) as stream:
            for event in stream:
                if event.type == "content_block_delta":
                    if hasattr(event.delta, 'text'):
                        if first_chunk:
                            stop_dots.set()
                            dot_thread.join(timeout=1)
                            print("\n\n")  # New line after dots
                            first_chunk = False
                        text = event.delta.text
                        print(text, end='', flush=True)
                        final_verdict_text += text

            final_response = stream.get_final_message()

        stop_dots.set()
        print("\n")

        if not final_verdict_text:
            final_verdict_text = final_response.content[0].text

        return {
            "iterations": iteration + 1,
            "tools_used": list(all_tool_results.keys()),
            "tool_results": all_tool_results,
            "conversion_artifacts": conversion_artifacts,
            "final_verdict": final_verdict_text,
            "verified": self._determine_if_verified(final_verdict_text)
        }

    def _execute_tool(self, tool_name: str, code: str, **kwargs) -> Dict:
        """Execute verification tool - assumes all tools are installed"""

        handlers = {
            "run_python_interpreter": self._run_python,
            "run_mypy": self._run_mypy,
            "run_pylint": self._run_pylint,
            "run_bandit": self._run_bandit,
            "run_flake8": self._run_flake8,
            "convert_python_to_c": self._convert_to_c,
            "run_esbmc": self._run_esbmc,
            "analyze_ast": self._analyze_ast,
            "run_deadlock_detector": self._run_deadlock_detector
        }

        handler = handlers.get(tool_name)
        if not handler:
            return {
                "tool": tool_name,
                "success": False,
                "output": f"Unknown tool: {tool_name}"
            }

        try:
            return handler(code, **kwargs)
        except Exception as e:
            return {
                "tool": tool_name,
                "success": False,
                "output": f"Tool execution error: {str(e)}",
                "error": str(e),
                "traceback": __import__('traceback').format_exc()
            }

    def _run_python(self, code: str, **kwargs) -> Dict:
        """Run Python interpreter"""
        with tempfile.NamedTemporaryFile(mode='w', suffix='.py', delete=False) as f:
            f.write(code)
            temp = f.name

        try:
            result = subprocess.run(
                ['python3', temp],
                capture_output=True,
                text=True,
                timeout=5
            )

            success = result.returncode == 0

            return {
                "tool": "python_interpreter",
                "success": success,
                "output": f"Exit code: {result.returncode}\n" +
                         (result.stdout if success else result.stderr),
                "stdout": result.stdout,
                "stderr": result.stderr,
                "return_code": result.returncode
            }
        except subprocess.TimeoutExpired:
            return {
                "tool": "python_interpreter",
                "success": False,
                "output": "Execution timeout after 5 seconds (infinite loop or hanging code)"
            }
        finally:
            os.unlink(temp)

    def _run_mypy(self, code: str, **kwargs) -> Dict:
        """Run mypy static type checker"""
        with tempfile.NamedTemporaryFile(mode='w', suffix='.py', delete=False) as f:
            f.write(code)
            temp = f.name

        try:
            result = subprocess.run(
                ['mypy', '--strict', '--no-error-summary', temp],
                capture_output=True,
                text=True,
                timeout=10
            )

            success = result.returncode == 0
            output = result.stdout + result.stderr

            if not output.strip():
                output = "✓ No type errors found (all type checks passed)"

            return {
                "tool": "mypy",
                "success": success,
                "output": output,
                "return_code": result.returncode
            }
        finally:
            os.unlink(temp)

    def _run_pylint(self, code: str, **kwargs) -> Dict:
        """Run pylint code quality checker"""
        with tempfile.NamedTemporaryFile(mode='w', suffix='.py', delete=False) as f:
            f.write(code)
            temp = f.name

        try:
            result = subprocess.run(
                ['pylint', temp, '--output-format=text', '--score=yes'],
                capture_output=True,
                text=True,
                timeout=10
            )

            # Pylint score is in the output
            output = result.stdout if result.stdout else "No output from pylint"

            # Success if score >= 8.0 or return code 0
            success = result.returncode == 0

            return {
                "tool": "pylint",
                "success": success,
                "output": output,
                "return_code": result.returncode
            }
        finally:
            os.unlink(temp)

    def _run_flake8(self, code: str, **kwargs) -> Dict:
        """Run flake8 style checker"""
        with tempfile.NamedTemporaryFile(mode='w', suffix='.py', delete=False) as f:
            f.write(code)
            temp = f.name

        try:
            result = subprocess.run(
                ['flake8', temp, '--max-line-length=100'],
                capture_output=True,
                text=True,
                timeout=10
            )

            success = result.returncode == 0
            output = result.stdout if result.stdout else "✓ No style violations found"

            return {
                "tool": "flake8",
                "success": success,
                "output": output,
                "return_code": result.returncode
            }
        finally:
            os.unlink(temp)

    def _run_bandit(self, code: str, **kwargs) -> Dict:
        """Run bandit security scanner"""
        with tempfile.NamedTemporaryFile(mode='w', suffix='.py', delete=False) as f:
            f.write(code)
            temp = f.name

        try:
            result = subprocess.run(
                ['bandit', '-f', 'json', temp],
                capture_output=True,
                text=True,
                timeout=10
            )

            try:
                report = json.loads(result.stdout)
                issues = report.get('results', [])
                success = len(issues) == 0

                if success:
                    output = "✓ No security issues found"
                else:
                    output = f"Found {len(issues)} security issue(s):\n"
                    for i, issue in enumerate(issues, 1):
                        severity = issue.get('issue_severity', 'UNKNOWN')
                        confidence = issue.get('issue_confidence', 'UNKNOWN')
                        text = issue.get('issue_text', '')
                        line = issue.get('line_number', '?')
                        output += f"\n{i}. [{severity}/{confidence}] Line {line}: {text}"

                return {
                    "tool": "bandit",
                    "success": success,
                    "output": output,
                    "issues": issues
                }
            except json.JSONDecodeError:
                return {
                    "tool": "bandit",
                    "success": False,
                    "output": f"Could not parse bandit output: {result.stdout}"
                }
        finally:
            os.unlink(temp)

    def _convert_to_c(self, code: str, analysis: dict = None, **kwargs) -> Dict:
        """Convert Python code to C for formal verification"""

        # Use analysis if provided
        if not analysis:
            analysis = {}

        # Check if this is ESBMC-specific Python code
        is_esbmc_code = 'esbmc.nondet' in code or 'import esbmc' in code

        # Enhanced Python-to-C conversion
        if is_esbmc_code:
            c_code = "#include <stdio.h>\n#include <stdlib.h>\n\n"
        else:
            c_code = "#include <stdio.h>\n#include <stdlib.h>\n#include <assert.h>\n\n"

        # Parse the Python code
        try:
            tree = ast.parse(code)
        except SyntaxError as e:
            return {
                "tool": "convert_python_to_c",
                "success": False,
                "output": f"Cannot convert: Python syntax error: {e}"
            }

        converted = False
        recommended_checks = []
        has_main_code = False
        main_code_lines = []

        # First pass: convert function definitions
        for node in tree.body:
            if isinstance(node, ast.FunctionDef):
                converted = True
                func_name = node.name

                # Extract return type from annotation
                return_type = "int"
                if node.returns:
                    if isinstance(node.returns, ast.Name):
                        py_type = node.returns.id
                        type_map = {'int': 'int', 'float': 'float', 'str': 'char*', 'bool': 'int'}
                        return_type = type_map.get(py_type, 'int')

                # For ESBMC code with large integers, use unsigned int
                if is_esbmc_code:
                    return_type = "unsigned int"

                # Build parameter list
                params = []
                for arg in node.args.args:
                    arg_type = "int"
                    if is_esbmc_code:
                        arg_type = "unsigned int"
                    if arg.annotation and isinstance(arg.annotation, ast.Name):
                        py_type = arg.annotation.id
                        type_map = {'int': 'int', 'float': 'float', 'str': 'char*', 'bool': 'int'}
                        arg_type = type_map.get(py_type, 'int')
                    params.append(f"{arg_type} {arg.arg}")

                param_str = ", ".join(params) if params else "void"

                c_code += f"{return_type} {func_name}({param_str}) {{\n"

                # Convert function body
                for stmt in node.body:
                    c_line = self._convert_statement(stmt, recommended_checks, is_esbmc_code)
                    if c_line:
                        c_code += c_line

                c_code += "}\n\n"

            elif isinstance(node, ast.Import):
                # Handle imports like "import esbmc"
                for alias in node.names:
                    if alias.name == 'esbmc':
                        # Add ESBMC nondet declarations
                        if 'unsigned int nondet_uint()' not in c_code:
                            c_code = c_code.replace("#include <stdlib.h>\n\n",
                                "#include <stdlib.h>\n\nunsigned int nondet_uint();\n\n")

            elif isinstance(node, (ast.Assign, ast.Expr, ast.Assert)):
                # These are main-level statements - save for main()
                has_main_code = True
                converted_stmt = self._convert_main_statement(node, is_esbmc_code)
                if converted_stmt:
                    main_code_lines.append(converted_stmt)

        if not converted and not has_main_code:
            return {
                "tool": "convert_python_to_c",
                "success": False,
                "output": "Could not convert: No suitable Python code found for conversion"
            }

        # Add main function
        c_code += "int main() {\n"

        if has_main_code and main_code_lines:
            # Use the actual code from the Python file
            for line in main_code_lines:
                c_code += f"    {line}\n"
        else:
            # Generic test harness
            c_code += "    // Converted from Python - ready for ESBMC verification\n"

        c_code += "    return 0;\n"
        c_code += "}\n"

        # Combine with AST analysis recommendations
        if analysis.get('recommended_esbmc_checks'):
            for check in analysis['recommended_esbmc_checks']:
                if check not in recommended_checks:
                    recommended_checks.append(check)

        # Save to current directory
        output_file = "converted_code.c"
        try:
            with open(output_file, 'w') as f:
                f.write(c_code)
            saved_msg = f"✓ Saved to: {os.path.abspath(output_file)}"
        except Exception as e:
            saved_msg = f"Warning: Could not save file: {e}"

        checks_msg = ""
        if recommended_checks:
            checks_msg = f"\n\n🔍 Recommended ESBMC checks: {', '.join(recommended_checks)}"
            checks_msg += f"\n💡 Use: run_esbmc with appropriate check flags"

        if is_esbmc_code:
            checks_msg += f"\n⚠️  Note: ESBMC-specific code detected - testing with unbounded nondeterministic values"

        return {
            "tool": "convert_python_to_c",
            "success": True,
            "output": f"Successfully converted Python to C ({len(c_code)} chars)\n{saved_msg}{checks_msg}",
            "c_code": c_code,
            "saved_file": output_file,
            "recommended_checks": recommended_checks
        }

    def _convert_statement(self, stmt, recommended_checks, is_esbmc_code):
        """Convert a single statement to C"""
        if isinstance(stmt, ast.Return):
            if isinstance(stmt.value, ast.BinOp):
                left = self._ast_to_c_expr(stmt.value.left)
                right = self._ast_to_c_expr(stmt.value.right)
                op = self._ast_op_to_c(stmt.value.op)

                if isinstance(stmt.value.op, (ast.Add, ast.Sub, ast.Mult)):
                    if 'overflow' not in recommended_checks:
                        recommended_checks.append('overflow')
                if isinstance(stmt.value.op, ast.Div):
                    if 'div-by-zero' not in recommended_checks:
                        recommended_checks.append('div-by-zero')

                return f"    return {left} {op} {right};\n"
            elif isinstance(stmt.value, ast.Constant):
                return f"    return {stmt.value.value};\n"
            elif isinstance(stmt.value, ast.Name):
                return f"    return {stmt.value.id};\n"
            else:
                return f"    return 0;  // Could not convert complex return\n"

        elif isinstance(stmt, ast.If):
            condition = self._ast_to_c_expr(stmt.test)
            result = f"    if ({condition}) {{\n"
            for if_stmt in stmt.body:
                sub_result = self._convert_statement(if_stmt, recommended_checks, is_esbmc_code)
                if sub_result:
                    result += "    " + sub_result
            result += "    }\n"
            return result

        elif isinstance(stmt, ast.Assign):
            if len(stmt.targets) == 1 and isinstance(stmt.targets[0], ast.Name):
                var_name = stmt.targets[0].id
                var_type = "unsigned int" if is_esbmc_code else "int"
                value = self._ast_to_c_expr(stmt.value)
                return f"    {var_type} {var_name} = {value};\n"

        elif isinstance(stmt, ast.While):
            condition = self._ast_to_c_expr(stmt.test)
            result = f"    while ({condition}) {{\n"
            for while_stmt in stmt.body:
                sub_result = self._convert_statement(while_stmt, recommended_checks, is_esbmc_code)
                if sub_result:
                    result += "    " + sub_result
            result += "    }\n"
            return result

        elif isinstance(stmt, ast.Expr) and isinstance(stmt.value, ast.Str):
            # Docstring - skip
            return ""

        return ""

    def _convert_main_statement(self, node, is_esbmc_code):
        """Convert main-level statements (assignments, asserts, etc.)"""
        if isinstance(node, ast.Assign):
            if len(node.targets) == 1 and isinstance(node.targets[0], ast.Name):
                var_name = node.targets[0].id

                # Check if RHS is esbmc.nondet_*() call
                if isinstance(node.value, ast.Call):
                    if isinstance(node.value.func, ast.Attribute):
                        if (isinstance(node.value.func.value, ast.Name) and
                            node.value.func.value.id == 'esbmc'):
                            # esbmc.nondet_uint() call
                            func_name = node.value.func.attr
                            if func_name == 'nondet_uint':
                                return f"unsigned int {var_name} = nondet_uint();"
                    elif isinstance(node.value.func, ast.Name):
                        # Regular function call
                        func_name = node.value.func.id
                        args = ', '.join([self._ast_to_c_expr(arg) for arg in node.value.args])
                        var_type = "unsigned int" if is_esbmc_code else "int"
                        return f"{var_type} {var_name} = {func_name}({args});"

        elif isinstance(node, ast.Assert):
            # Convert assert to __ESBMC_assert if ESBMC code
            condition = self._ast_to_c_expr(node.test)
            if is_esbmc_code:
                return f'__ESBMC_assert({condition}, "assertion");'
            else:
                return f"assert({condition});"

        return ""

    def _ast_to_c_expr(self, node) -> str:
        """Convert AST node to C expression"""
        if isinstance(node, ast.Name):
            return node.id
        elif isinstance(node, ast.Constant):
            return str(node.value)
        elif isinstance(node, ast.BinOp):
            left = self._ast_to_c_expr(node.left)
            right = self._ast_to_c_expr(node.right)
            op = self._ast_op_to_c(node.op)
            return f"({left} {op} {right})"
        elif isinstance(node, ast.Compare):
            left = self._ast_to_c_expr(node.left)
            op = self._ast_comp_to_c(node.ops[0])
            right = self._ast_to_c_expr(node.comparators[0])
            return f"{left} {op} {right}"
        elif isinstance(node, ast.Call):
            if isinstance(node.func, ast.Attribute):
                # Handle esbmc.nondet_uint() etc
                if isinstance(node.func.value, ast.Name) and node.func.value.id == 'esbmc':
                    return f"{node.func.attr}()"
            elif isinstance(node.func, ast.Name):
                func_name = node.func.id
                args = ', '.join([self._ast_to_c_expr(arg) for arg in node.args])
                return f"{func_name}({args})"
            return "0"
        elif isinstance(node, ast.FloorDiv):
            # Floor division in Python should be regular division in C for integers
            return "/"
        else:
            return "0"

    def _ast_op_to_c(self, op) -> str:
        """Convert AST operator to C operator"""
        op_map = {
            ast.Add: '+', ast.Sub: '-', ast.Mult: '*',
            ast.Div: '/', ast.Mod: '%', ast.FloorDiv: '/'
        }
        return op_map.get(type(op), '+')

    def _ast_comp_to_c(self, op) -> str:
        """Convert AST comparison to C comparison"""
        comp_map = {
            ast.Eq: '==', ast.NotEq: '!=', ast.Lt: '<',
            ast.LtE: '<=', ast.Gt: '>', ast.GtE: '>='
        }
        return comp_map.get(type(op), '==')

    def _run_esbmc(self, code: str, check_overflow: bool = False, check_bounds: bool = False,
                   check_div_by_zero: bool = False, check_deadlock: bool = False,
                   check_pointer: bool = False, check_memory_leak: bool = False, **kwargs) -> Dict:
        """Run ESBMC formal verification on C code with intelligent check selection and error recovery"""

        # Save to current directory instead of temp file
        output_file = "esbmc_verify.c"
        try:
            with open(output_file, 'w') as f:
                f.write(code)
            print(f"      📁 Saved C code to: {os.path.abspath(output_file)}")
        except Exception as e:
            return {
                "tool": "esbmc",
                "success": False,
                "output": f"Could not save C file: {e}"
            }

        try:
            # Try with moderate unwind first
            unwind = 10
            esbmc_timeout = 30 if not (check_overflow or check_memory_leak) else 60

            print(f"      🔍 Starting verification with unwind={unwind}, timeout={esbmc_timeout}s")

            result = self._run_esbmc_attempt(
                output_file, code,
                unwind=unwind,
                timeout=esbmc_timeout,
                check_overflow=check_overflow,
                check_deadlock=check_deadlock,
                check_memory_leak=check_memory_leak
            )

            # Check for unwinding assertion (needs more unwind)
            if 'unwinding assertion' in result.get('output', ''):
                print(f"      ⚠️  Unwinding assertion detected - loop needs more iterations")
                print(f"      🔄 Retrying with unwind=20 (max)...")

                result = self._run_esbmc_attempt(
                    output_file, code,
                    unwind=20,
                    timeout=esbmc_timeout,
                    check_overflow=check_overflow,
                    check_deadlock=check_deadlock,
                    check_memory_leak=check_memory_leak
                )

                # Still unwinding assertion? Report to Claude
                if 'unwinding assertion' in result.get('output', ''):
                    unwinding_guidance = "\n\n" + "="*60 + "\n"
                    unwinding_guidance += "⚠️  UNWINDING LIMIT REACHED (max=20)\n"
                    unwinding_guidance += "="*60 + "\n"
                    unwinding_guidance += "The loop requires more than 20 iterations to fully verify.\n\n"
                    unwinding_guidance += "💡 Suggestions:\n"
                    unwinding_guidance += "1. Add explicit loop bounds to the C code\n"
                    unwinding_guidance += "2. Add __ESBMC_assume() constraints to limit iterations\n"
                    unwinding_guidance += "3. Simplify the loop logic if possible\n"
                    unwinding_guidance += "4. Use convert_python_to_c again with bounded loops\n"

                    result['output'] = result.get('output', '') + unwinding_guidance
                    result['unwinding_limit_reached'] = True

            # Check if it timed out (actual timeout, not verification failure!)
            if self._esbmc_timed_out(result):
                print(f"      ⏱️  Timeout detected")

                # Try with smaller unwind and basic checks
                print(f"      🔄 Retry with unwind=5 and basic checks only...")
                result = self._run_esbmc_attempt(
                    output_file, code,
                    unwind=5,
                    timeout=30,
                    check_overflow=False,
                    check_deadlock=False,
                    check_memory_leak=False
                )

                if self._esbmc_timed_out(result):
                    # Give up and report to Claude
                    timeout_guidance = "\n\n" + "="*60 + "\n"
                    timeout_guidance += "⏱️  VERIFICATION TIMEOUT\n"
                    timeout_guidance += "="*60 + "\n"
                    timeout_guidance += "The C code is too complex for ESBMC to verify in the time limit.\n\n"
                    timeout_guidance += "💡 Suggestions:\n"
                    timeout_guidance += "1. Regenerate simpler C code:\n"
                    timeout_guidance += "   - Add bounds to nondeterministic values (__ESBMC_assume(n < 1000))\n"
                    timeout_guidance += "   - Add loop bounds (counter with break statement)\n"
                    timeout_guidance += "   - Simplify complex expressions\n"
                    timeout_guidance += "   - Remove unnecessary code paths\n"
                    timeout_guidance += "2. Use convert_python_to_c again with these constraints\n"
                    timeout_guidance += "3. Then retry ESBMC with the simpler code\n"

                    result['output'] = result.get('output', '') + timeout_guidance
                    result['success'] = False
                    result['timeout_occurred'] = True
                    return result

            return result

        except FileNotFoundError:
            esbmc_location = f"at {self.esbmc_path}" if self.esbmc_path != 'esbmc' else "in PATH"
            return {
                "tool": "esbmc",
                "success": False,
                "output": f"ESBMC not found {esbmc_location}.\n" +
                         f"Install from: https://github.com/esbmc/esbmc\n" +
                         f"Or specify path with: --esbmc-path /path/to/esbmc\n" +
                         f"Or set environment variable: export ESBMC_PATH=/path/to/esbmc\n\n" +
                         "This is optional for basic verification."
            }

    def _esbmc_timed_out(self, result: Dict) -> bool:
        """Check if ESBMC timed out (NOT verification failure!)"""
        output = result.get('output', '')
        return_code = result.get('return_code', 0)

        # Check for actual timeout indicators
        is_timeout = (
            'Timed out' in output or
            ('timeout' in output.lower() and 'timeout' not in output.lower().split('--timeout')[0] if '--timeout' in output.lower() else 'timeout' in output.lower()) or
            return_code == 124  # Timeout return code
        )

        # Make sure it's not a verification failure (which is actually success!)
        is_verification_failure = 'VERIFICATION FAILED' in output

        # Timeout is only if we timed out AND didn't get a verification result
        return is_timeout and not is_verification_failure

    def _run_esbmc_attempt(self, filename: str, code: str, unwind: int, timeout: int,
                          check_overflow: bool = False, check_deadlock: bool = False,
                          check_memory_leak: bool = False) -> Dict:
        """Single ESBMC verification attempt with specific parameters"""

        esbmc_cmd = [self.esbmc_path, filename, '--unwind', str(unwind), '--timeout', str(timeout)]

        enabled_checks = ['bounds-check', 'div-by-zero-check', 'pointer-check']

        if check_overflow:
            esbmc_cmd.append('--overflow-check')
            enabled_checks.append('overflow')

        if check_deadlock:
            esbmc_cmd.append('--deadlock-check')
            enabled_checks.append('deadlock')

        if check_memory_leak:
            esbmc_cmd.append('--memory-leak-check')
            enabled_checks.append('memory-leak')

        print(f"      🚀 Running: {' '.join(esbmc_cmd)}")
        print(f"      📡 Streaming output:\n")

        try:
            # Use Popen for live streaming
            import time
            process = subprocess.Popen(
                esbmc_cmd,
                stdout=subprocess.PIPE,
                stderr=subprocess.STDOUT,
                text=True,
                bufsize=1,  # Line buffered
                universal_newlines=True
            )

            output_lines = []
            start_time = time.time()

            # Stream output line by line
            try:
                for line in process.stdout:
                    # Print live
                    print(f"         {line}", end='')
                    output_lines.append(line)

                    # Check timeout manually
                    if time.time() - start_time > timeout + 10:
                        process.kill()
                        output_lines.append("\n⏱️  ESBMC timeout - process killed\n")
                        break

                process.wait(timeout=5)  # Wait for process to finish
                return_code = process.returncode

            except Exception as e:
                process.kill()
                output_lines.append(f"\n❌ Error during streaming: {str(e)}\n")
                return_code = -1

            full_output = ''.join(output_lines)

            # Check for option errors and retry if needed
            if 'unrecognised option' in full_output or 'unknown_option' in full_output:
                import re
                match = re.search(r"unrecognised option '([^']+)'", full_output)
                if match:
                    bad_option = match.group(1)
                    if not bad_option.startswith('--'):
                        bad_option = '--' + bad_option

                    fixed_cmd = [arg for arg in esbmc_cmd if arg != bad_option]
                    print(f"\n      🔧 Removed bad option: {bad_option}")
                    print(f"      🔄 Retrying with fixed command...\n")

                    # Recursive retry with fixed command
                    process = subprocess.Popen(
                        fixed_cmd,
                        stdout=subprocess.PIPE,
                        stderr=subprocess.STDOUT,
                        text=True,
                        bufsize=1,
                        universal_newlines=True
                    )

                    output_lines = []
                    start_time = time.time()

                    for line in process.stdout:
                        print(f"         {line}", end='')
                        output_lines.append(line)

                        if time.time() - start_time > timeout + 10:
                            process.kill()
                            output_lines.append("\n⏱️  ESBMC timeout - process killed\n")
                            break

                    process.wait(timeout=5)
                    return_code = process.returncode
                    full_output = ''.join(output_lines)
                    esbmc_cmd = fixed_cmd

            print()  # New line after streaming

            success = return_code == 0 and 'VERIFICATION SUCCESSFUL' in full_output

            inspection_note = f"\n📝 C file: {os.path.abspath(filename)}"
            inspection_note += f"\n💡 Command: {' '.join(esbmc_cmd)}"

            return {
                "tool": "esbmc",
                "success": success,
                "output": full_output + inspection_note,
                "return_code": return_code,
                "enabled_checks": enabled_checks,
                "saved_file": filename,
                "command": ' '.join(esbmc_cmd)
            }

        except FileNotFoundError:
            return {
                "tool": "esbmc",
                "success": False,
                "output": "ESBMC command not found",
                "return_code": -1,
                "enabled_checks": enabled_checks,
                "saved_file": filename,
                "command": ' '.join(esbmc_cmd)
            }
        except Exception as e:
            return {
                "tool": "esbmc",
                "success": False,
                "output": f"Error: {str(e)}",
                "return_code": -1,
                "enabled_checks": enabled_checks,
                "saved_file": filename,
                "command": ' '.join(esbmc_cmd)
            }

    def _run_deadlock_detector(self, code: str, timeout: int = 5, **kwargs) -> Dict:
        """Advanced runtime deadlock detection for Python threading code"""

        # Create instrumented wrapper code
        instrumented_code = '''
import threading
import time
import sys
from collections import defaultdict

# Global state for deadlock detection
lock_graph = defaultdict(set)  # thread_id -> set of locks held
wait_graph = defaultdict(set)  # thread_id -> lock waiting for
lock_holders = {}  # lock_id -> thread_id holding it
lock_order = defaultdict(list)  # thread_id -> ordered list of lock acquisitions
all_locks = {}  # lock_id -> lock object
deadlock_detected = []
lock_events = []

class InstrumentedLock:
    """Wrapper for threading.Lock with deadlock detection"""
    _lock_counter = 0
    _counter_lock = threading.Lock()

    def __init__(self, original_lock):
        self._lock = original_lock
        with InstrumentedLock._counter_lock:
            self.lock_id = InstrumentedLock._lock_counter
            InstrumentedLock._lock_counter += 1  # Fixed: was _counter_lock
        all_locks[self.lock_id] = self

    def acquire(self, blocking=True, timeout=-1):
        thread_id = threading.get_ident()
        thread_name = threading.current_thread().name

        lock_events.append(f"[{thread_name}] Attempting to acquire Lock#{self.lock_id}")

        # Check for potential deadlock before acquiring
        wait_graph[thread_id].add(self.lock_id)

        # Detect circular wait
        if self._detect_cycle(thread_id):
            cycle_info = self._get_cycle_info(thread_id)
            deadlock_detected.append({
                'type': 'circular_wait',
                'thread': thread_name,
                'cycle': cycle_info,
                'message': f"Circular wait detected: {cycle_info}"
            })
            lock_events.append(f"[{thread_name}] ⚠️  CIRCULAR WAIT DETECTED: {cycle_info}")

        # Try to acquire with timeout
        start_time = time.time()

        # Handle timeout parameter correctly
        if timeout == -1:
            acquired = self._lock.acquire(blocking=blocking)
        else:
            acquired = self._lock.acquire(blocking=blocking, timeout=timeout)

        wait_time = time.time() - start_time

        if acquired:
            wait_graph[thread_id].discard(self.lock_id)
            lock_graph[thread_id].add(self.lock_id)
            lock_holders[self.lock_id] = thread_id
            lock_order[thread_id].append(self.lock_id)
            lock_events.append(f"[{thread_name}] ✓ Acquired Lock#{self.lock_id} (waited {wait_time:.3f}s)")

            # Check for inconsistent lock ordering
            self._check_lock_ordering(thread_id)
        else:
            lock_events.append(f"[{thread_name}] ✗ Failed to acquire Lock#{self.lock_id}")
            wait_graph[thread_id].discard(self.lock_id)

        return acquired

    def release(self):
        thread_id = threading.get_ident()
        thread_name = threading.current_thread().name

        if self.lock_id in lock_graph[thread_id]:
            lock_graph[thread_id].discard(self.lock_id)
            if self.lock_id in lock_order[thread_id]:
                lock_order[thread_id].remove(self.lock_id)

        if lock_holders.get(self.lock_id) == thread_id:
            del lock_holders[self.lock_id]

        self._lock.release()
        lock_events.append(f"[{thread_name}] Released Lock#{self.lock_id}")

    def _detect_cycle(self, start_thread):
        """Detect if there's a circular wait condition"""
        visited = set()
        rec_stack = set()

        def dfs(thread_id):
            visited.add(thread_id)
            rec_stack.add(thread_id)

            # Get locks this thread is waiting for
            for lock_id in wait_graph[thread_id]:
                # Who holds this lock?
                holder = lock_holders.get(lock_id)
                if holder is not None:
                    if holder == start_thread:
                        return True  # Cycle found!
                    if holder not in visited:
                        if dfs(holder):
                            return True
                    elif holder in rec_stack:
                        return True

            rec_stack.discard(thread_id)
            return False

        return dfs(start_thread)

    def _get_cycle_info(self, thread_id):
        """Get detailed cycle information"""
        cycles = []
        for lock_id in wait_graph[thread_id]:
            holder = lock_holders.get(lock_id)
            if holder:
                try:
                    holder_thread = threading._active.get(holder)
                    holder_name = holder_thread.name if holder_thread else f"Thread-{holder}"
                except:
                    holder_name = f"Thread-{holder}"
                cycles.append(f"Thread[{threading.current_thread().name}] waits for Lock#{lock_id} held by Thread[{holder_name}]")
        return " -> ".join(cycles) if cycles else "Unknown cycle"

    def _check_lock_ordering(self, thread_id):
        """Check for inconsistent lock ordering (potential future deadlock)"""
        current_order = lock_order[thread_id]
        if len(current_order) >= 2:
            # Check if this ordering conflicts with other threads
            for other_thread, other_order in lock_order.items():
                if other_thread != thread_id and len(other_order) >= 2:
                    # Look for reversed pairs
                    for i in range(len(current_order) - 1):
                        for j in range(len(other_order) - 1):
                            if (current_order[i] == other_order[j+1] and
                                current_order[i+1] == other_order[j]):
                                deadlock_detected.append({
                                    'type': 'lock_ordering_violation',
                                    'thread': threading.current_thread().name,
                                    'message': f"Inconsistent lock ordering detected: This thread acquires Lock#{current_order[i]} then Lock#{current_order[i+1]}, but another thread acquires them in reverse order"
                                })
                                lock_events.append(f"[{threading.current_thread().name}] ⚠️  LOCK ORDERING VIOLATION detected")

    def __enter__(self):
        self.acquire()
        return self

    def __exit__(self, exc_type, exc_val, exc_tb):
        self.release()
        return False

# Monkey-patch threading.Lock
_original_Lock = threading.Lock
def _instrumented_Lock():
    return InstrumentedLock(_original_Lock())
threading.Lock = _instrumented_Lock

# User code starts here
try:
''' + '\n'.join('    ' + line for line in code.split('\n')) + '''
except Exception as e:
    print(f"\\n❌ Exception during execution: {e}", file=sys.stderr)
    import traceback
    traceback.print_exc()
# User code ends here

# Print summary
if deadlock_detected or lock_events:
    print("\\n" + "="*60)
    print("DEADLOCK DETECTION SUMMARY")
    print("="*60)

    if deadlock_detected:
        print(f"\\n⚠️  Found {len(deadlock_detected)} potential deadlock issue(s):\\n")
        for i, issue in enumerate(deadlock_detected, 1):
            print(f"{i}. [{issue['type']}] {issue['message']}")

    if lock_events:
        print(f"\\n📋 Lock Event Trace ({len(lock_events)} events):\\n")
        for event in lock_events:
            print(f"  {event}")
'''

        # Write to temp file and execute
        with tempfile.NamedTemporaryFile(mode='w', suffix='.py', delete=False) as f:
            f.write(instrumented_code)
            temp = f.name

        try:
            # Run with timeout
            result = subprocess.run(
                ['python3', temp],
                capture_output=True,
                text=True,
                timeout=timeout
            )

            # Parse output for deadlock info
            output = result.stdout + result.stderr

            # Check for actual deadlock (timeout while running)
            if result.returncode != 0 and "Timeout" not in output:
                # Check if threads were blocked
                if "lock" in output.lower() or "thread" in output.lower():
                    output += "\n\n⚠️  Execution failed with threading-related error - possible deadlock"

            success = (result.returncode == 0 and
                      "CIRCULAR WAIT" not in output and
                      "LOCK ORDERING VIOLATION" not in output and
                      "Found" not in output.split("potential deadlock issue")[0] if "potential deadlock issue" in output else True)

            if success:
                output = "✓ No deadlocks detected\n\n" + output
            else:
                output = "❌ Potential deadlock issues detected\n\n" + output

            return {
                "tool": "deadlock_detector",
                "success": success,
                "output": output,
                "return_code": result.returncode
            }

        except subprocess.TimeoutExpired:
            # Actual deadlock - threads hung
            output = "❌ DEADLOCK DETECTED - Execution timed out\n\n"
            output += f"The code did not complete within {timeout} seconds.\n"
            output += "This indicates threads are blocked waiting for each other (deadlock).\n\n"
            output += "Common causes:\n"
            output += "  • Thread A holds Lock1, waits for Lock2\n"
            output += "  • Thread B holds Lock2, waits for Lock1\n"
            output += "  • Neither can proceed → deadlock\n"

            return {
                "tool": "deadlock_detector",
                "success": False,
                "output": output,
                "return_code": 124
            }
        finally:
            os.unlink(temp)

    def _analyze_ast(self, code: str, **kwargs) -> Dict:
        """Analyze Python AST"""
        try:
            tree = ast.parse(code)

            analysis = {
                "functions": [],
                "classes": [],
                "imports": [],
                "has_loops": False,
                "has_conditionals": False,
                "has_exceptions": False,
                "has_type_hints": False,
                "has_division": False,
                "has_array_access": False,
                "has_threading": False,
                "has_arithmetic": False,
                "has_multiplication": False,
                "has_pointer_ops": False,
                "max_loop_depth": 0
            }

            loop_depth = 0

            for node in ast.walk(tree):
                if isinstance(node, ast.FunctionDef):
                    analysis["functions"].append(node.name)
                    if node.returns or any(arg.annotation for arg in node.args.args):
                        analysis["has_type_hints"] = True
                elif isinstance(node, ast.ClassDef):
                    analysis["classes"].append(node.name)
                elif isinstance(node, (ast.For, ast.While)):
                    analysis["has_loops"] = True
                    loop_depth += 1
                    analysis["max_loop_depth"] = max(analysis["max_loop_depth"], loop_depth)
                elif isinstance(node, ast.If):
                    analysis["has_conditionals"] = True
                elif isinstance(node, (ast.Try, ast.Raise)):
                    analysis["has_exceptions"] = True
                elif isinstance(node, (ast.Import, ast.ImportFrom)):
                    if isinstance(node, ast.Import):
                        for alias in node.names:
                            analysis["imports"].append(alias.name)
                            if 'threading' in alias.name:
                                analysis["has_threading"] = True
                    elif node.module:
                        analysis["imports"].append(node.module)
                        if 'threading' in node.module:
                            analysis["has_threading"] = True
                elif isinstance(node, ast.Div):
                    analysis["has_division"] = True
                elif isinstance(node, ast.Subscript):
                    analysis["has_array_access"] = True
                elif isinstance(node, (ast.Add, ast.Sub)):
                    analysis["has_arithmetic"] = True
                elif isinstance(node, ast.Mult):
                    analysis["has_arithmetic"] = True
                    analysis["has_multiplication"] = True
                elif isinstance(node, ast.Attribute):
                    # Detect pointer-like operations (attribute access can translate to pointers in C)
                    analysis["has_pointer_ops"] = True

            # Determine recommended ESBMC checks
            esbmc_checks = []
            if analysis["has_arithmetic"] or analysis["has_multiplication"]:
                esbmc_checks.append("overflow")
            if analysis["has_array_access"]:
                esbmc_checks.append("bounds")
            if analysis["has_division"]:
                esbmc_checks.append("div-by-zero")
            if analysis["has_pointer_ops"]:
                esbmc_checks.append("pointer")

            analysis["recommended_esbmc_checks"] = esbmc_checks

            output = "="*60 + "\n"
            output += "AST ANALYSIS REPORT\n"
            output += "="*60 + "\n\n"
            output += f"Functions: {', '.join(analysis['functions']) if analysis['functions'] else 'None'}\n"
            output += f"Classes: {', '.join(analysis['classes']) if analysis['classes'] else 'None'}\n"
            output += f"Imports: {', '.join(analysis['imports']) if analysis['imports'] else 'None'}\n"
            output += f"\nCode Characteristics:\n"
            output += f"  • Has type hints: {'Yes' if analysis['has_type_hints'] else 'No'}\n"
            output += f"  • Has loops: {'Yes' if analysis['has_loops'] else 'No'}"
            if analysis['has_loops']:
                output += f" (max depth: {analysis['max_loop_depth']})\n"
            else:
                output += "\n"
            output += f"  • Has conditionals: {'Yes' if analysis['has_conditionals'] else 'No'}\n"
            output += f"  • Has exception handling: {'Yes' if analysis['has_exceptions'] else 'No'}\n"
            output += f"  • Has arithmetic operations: {'Yes' if analysis['has_arithmetic'] else 'No'}\n"
            output += f"  • Has multiplication: {'Yes' if analysis['has_multiplication'] else 'No'}\n"
            output += f"  • Has division operations: {'Yes' if analysis['has_division'] else 'No'}\n"
            output += f"  • Has array/subscript access: {'Yes' if analysis['has_array_access'] else 'No'}\n"
            output += f"  • Uses threading: {'Yes ⚠️' if analysis['has_threading'] else 'No'}\n"

            output += "\n🔍 Verification Recommendations:\n"

            recommendations = []
            if analysis['has_type_hints']:
                recommendations.append("  • mypy (type checking)")

            if analysis['has_threading']:
                recommendations.append("  • run_deadlock_detector (RECOMMENDED for threading - much better than ESBMC)")

            if esbmc_checks and not analysis['has_threading']:
                checks_str = ", ".join(esbmc_checks)
                recommendations.append(f"  • convert_python_to_c + esbmc with checks: {checks_str}")
            elif (analysis['has_division'] or analysis['has_array_access']) and not analysis['has_threading']:
                recommendations.append("  • convert_python_to_c + esbmc (formal verification)")

            if 'os' in analysis['imports'] or 'subprocess' in analysis['imports']:
                recommendations.append("  • bandit (security scanning)")
            recommendations.append("  • pylint (code quality)")
            recommendations.append("  • flake8 (style checking)")

            if analysis['has_threading']:
                output += "\n⚠️  THREADING DETECTED:\n"
                output += "  Use run_deadlock_detector for reliable concurrency verification.\n"
                output += "  Python-to-C conversion loses threading semantics!\n\n"

            output += "\n".join(recommendations)

            return {
                "tool": "analyze_ast",
                "success": True,
                "output": output,
                "analysis": analysis
            }

        except SyntaxError as e:
            return {
                "tool": "analyze_ast",
                "success": False,
                "output": f"Syntax error in code: {str(e)}"
            }

    def _format_tool_result(self, result: Dict) -> str:
        """Format tool result for Claude with smart truncation"""
        output = "="*60 + "\n"
        output += f"TOOL: {result.get('tool', 'unknown').upper()}\n"
        output += f"STATUS: {'✅ SUCCESS' if result.get('success') else '❌ FAILED'}\n"

        if result.get('enabled_checks'):
            output += f"ENABLED CHECKS: {', '.join(result['enabled_checks'])}\n"

        if result.get('recommended_checks'):
            output += f"RECOMMENDED CHECKS: {', '.join(result['recommended_checks'])}\n"

        if result.get('saved_file'):
            output += f"SAVED FILE: {result['saved_file']}\n"

        if result.get('command'):
            output += f"COMMAND: {result['command']}\n"

        output += "="*60 + "\n\n"

        # Truncate very long outputs to prevent context overflow
        tool_output = result.get('output', 'No output')
        max_output_length = 5000  # Max characters for tool output

        if len(tool_output) > max_output_length:
            # For ESBMC, try to extract key information
            if result.get('tool') == 'esbmc':
                truncated = self._truncate_esbmc_output(tool_output, max_output_length)
                output += truncated
            else:
                # Generic truncation
                output += tool_output[:max_output_length]
                output += f"\n\n... [TRUNCATED - output was {len(tool_output)} chars, showing first {max_output_length}] ...\n"
        else:
            output += tool_output + "\n"

        # Don't include full C code in formatted results to save space
        # It's already saved to file
        if result.get('c_code'):
            c_code_len = len(result['c_code'])
            output += "\n" + "-"*60 + "\n"
            output += f"GENERATED C CODE: {c_code_len} chars (saved to {result.get('saved_file', 'file')})\n"
            output += "-"*60 + "\n"

        return output

    def _truncate_esbmc_output(self, output: str, max_length: int) -> str:
        """Intelligently truncate ESBMC output to keep important parts"""
        lines = output.split('\n')

        # Extract key sections
        important_lines = []
        in_violation = False
        violation_lines = []

        for line in lines:
            # Keep version info
            if 'ESBMC version' in line:
                important_lines.append(line)
            # Keep verification result
            elif 'VERIFICATION SUCCESSFUL' in line or 'VERIFICATION FAILED' in line:
                important_lines.append(line)
            # Track violation details
            elif 'Violated property:' in line:
                in_violation = True
                violation_lines.append(line)
            elif in_violation:
                violation_lines.append(line)
                if len(violation_lines) > 30:  # Limit violation trace
                    in_violation = False
            # Keep error messages
            elif 'error:' in line.lower() or 'warning:' in line.lower():
                important_lines.append(line)

        # Combine sections
        result = '\n'.join(important_lines[:10])  # First 10 important lines

        if violation_lines:
            result += '\n\nViolation Details:\n'
            result += '\n'.join(violation_lines[:25])  # First 25 lines of violation
            if len(violation_lines) > 25:
                result += f'\n... [truncated {len(violation_lines) - 25} more violation lines] ...'

        # Add file location note
        result += '\n\n📝 Full output available in esbmc_verify.c location'
        result += '\n💡 To see complete output, run the command manually'

        return result

    def _determine_if_verified(self, verdict_text: str) -> bool:
        """Determine if code is verified from verdict text"""
        text_lower = verdict_text.lower()

        # Strong negative indicators
        strong_negative = ['failed', 'unsafe', 'critical', 'error', 'violation', 'vulnerability']
        if any(indicator in text_lower for indicator in strong_negative):
            return False

        # Positive indicators
        positive = ['verified', 'successful', 'passed', 'safe', 'correct', 'no issues', 'looks good']
        positive_count = sum(1 for indicator in positive if indicator in text_lower)

        return positive_count >= 2  # Need at least 2 positive indicators


if __name__ == "__main__":
    import sys
    import argparse
    from dotenv import load_dotenv

    # Load environment variables from .env file
    load_dotenv()

    # Parse command-line arguments
    parser = argparse.ArgumentParser(
        description='Enhanced Python Code Verification Agent using Claude AI',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  # Run demo
  python enhanced_verification_agent.py

  # Verify a file
  python enhanced_verification_agent.py mycode.py

  # Use custom ESBMC location
  python enhanced_verification_agent.py mycode.py --esbmc-path /usr/local/bin/esbmc
  python enhanced_verification_agent.py mycode.py --esbmc-path ./esbmc-build/bin/esbmc

  # Use ESBMC_PATH environment variable
  export ESBMC_PATH=/path/to/esbmc
  python enhanced_verification_agent.py mycode.py

  # Force specific tools
  python enhanced_verification_agent.py mycode.py --force-esbmc
  python enhanced_verification_agent.py mycode.py --force-mypy --force-bandit
  python enhanced_verification_agent.py threading_code.py --force-deadlock

  # Set max iterations
  python enhanced_verification_agent.py mycode.py --max-iterations 15
        """
    )

    parser.add_argument('file', nargs='?', help='Python file to verify')
    parser.add_argument('--max-iterations', type=int, default=10,
                       help='Maximum verification iterations (default: 10)')
    parser.add_argument('--esbmc-path', type=str, default=None,
                       help='Path to ESBMC executable (default: esbmc in PATH, or ESBMC_PATH env var)')
    parser.add_argument('--force-ast', action='store_true',
                       help='Force AST analysis')
    parser.add_argument('--force-mypy', action='store_true',
                       help='Force mypy type checking')
    parser.add_argument('--force-pylint', action='store_true',
                       help='Force pylint code quality check')
    parser.add_argument('--force-flake8', action='store_true',
                       help='Force flake8 style check')
    parser.add_argument('--force-bandit', action='store_true',
                       help='Force bandit security scan')
    parser.add_argument('--force-python', action='store_true',
                       help='Force Python interpreter execution')
    parser.add_argument('--force-deadlock', action='store_true',
                       help='Force runtime deadlock detector for threading code')
    parser.add_argument('--force-esbmc', action='store_true',
                       help='Force ESBMC formal verification (includes Python-to-C conversion)')

    args = parser.parse_args()

    api_key = os.environ.get("ANTHROPIC_API_KEY")
    if not api_key:
        print("❌ Error: ANTHROPIC_API_KEY not found")
        print("Please create a .env file with:")
        print("ANTHROPIC_API_KEY=your-key-here")
        print("\nOr set environment variable:")
        print("export ANTHROPIC_API_KEY='your-key-here'")
        sys.exit(1)

    # Build list of forced tools
    force_tools = []
    if args.force_ast:
        force_tools.append('analyze_ast')
    if args.force_mypy:
        force_tools.append('run_mypy')
    if args.force_pylint:
        force_tools.append('run_pylint')
    if args.force_flake8:
        force_tools.append('run_flake8')
    if args.force_bandit:
        force_tools.append('run_bandit')
    if args.force_python:
        force_tools.append('run_python_interpreter')
    if args.force_deadlock:
        force_tools.append('run_deadlock_detector')
    if args.force_esbmc:
        force_tools.append('convert_python_to_c')
        force_tools.append('run_esbmc')

    if force_tools:
        print(f"🔧 Forced tools: {', '.join(force_tools)}\n")

    if args.esbmc_path:
        print(f"🔧 Using ESBMC from: {args.esbmc_path}\n")

    # Test cases
    test_cases = [
        ("Type-Annotated Division", """def divide(a: int, b: int) -> float:
    \"\"\"Safely divide two numbers.\"\"\"
    if b != 0:
        return a / b
    return 0.0

result = divide(10, 2)
assert result == 5.0
print(f"Result: {result}")"""),

        ("Unsafe Division", """def divide(a, b):
    return a / b

result = divide(10, 0)
print(result)"""),

        ("Security Vulnerability", """import os
import subprocess

def run_command(user_input):
    # Potential command injection vulnerability
    os.system(user_input)

run_command("ls -la")"""),

        ("Complex with Multiple Issues", """import subprocess

def process_data(items: list) -> int:
    total = 0
    for i in range(len(items) + 1):  # Off-by-one error
        total = total + items[i]  # Array bounds issue

    count = len(items)
    average = total / count  # Potential division by zero

    # Security issue
    cmd = f"echo {total}"
    subprocess.call(cmd, shell=True)

    return average
"""),

        ("Threading Deadlock", """import threading
import time

lock1 = threading.Lock()
lock2 = threading.Lock()

def thread1():
    with lock1:
        print("Thread 1 acquired lock1")
        time.sleep(0.1)
        with lock2:
            print("Thread 1 acquired lock2")

def thread2():
    with lock2:
        print("Thread 2 acquired lock2")
        time.sleep(0.1)
        with lock1:
            print("Thread 2 acquired lock1")

t1 = threading.Thread(target=thread1)
t2 = threading.Thread(target=thread2)
t1.start()
t2.start()
t1.join()
t2.join()
print("Done")
""")
    ]

    if args.file:
        # Verify file provided as argument
        with open(args.file) as f:
            code = f.read()

        agent = EnhancedVerificationAgent(
            api_key=api_key,
            force_tools=force_tools,
            esbmc_path=args.esbmc_path
        )
        result = agent.verify(code, max_iterations=args.max_iterations)

        print(f"\n{'='*80}")
        print("VERIFICATION SUMMARY")
        print(f"{'='*80}")
        print(f"Iterations: {result['iterations']}")
        print(f"Tools used: {', '.join(result['tools_used'])}")
        print(f"Verified: {'✅ YES' if result['verified'] else '❌ NO'}")

        # Show ESBMC checks if used
        if 'run_esbmc' in result['tools_used']:
            esbmc_results = result['tool_results'].get('run_esbmc', [])
            if esbmc_results:
                last_esbmc = esbmc_results[-1]
                if last_esbmc.get('enabled_checks'):
                    print(f"ESBMC checks: {', '.join(last_esbmc['enabled_checks'])}")

        # Show saved files
        if result.get('conversion_artifacts') and result['conversion_artifacts'].get('c_code'):
            print(f"\n📁 Generated Files:")
            print(f"   - converted_code.c (Python→C conversion)")
            if 'run_esbmc' in result['tools_used']:
                print(f"   - esbmc_verify.c (ESBMC verification)")
                esbmc_results = result['tool_results'].get('run_esbmc', [])
                if esbmc_results and esbmc_results[-1].get('command'):
                    print(f"\n💡 Test ESBMC manually:")
                    print(f"   {esbmc_results[-1]['command']}")

        # Show saved files
        if result.get('conversion_artifacts') and result['conversion_artifacts'].get('c_code'):
            print(f"\n📁 Generated Files:")
            print(f"   - converted_code.c (Python→C conversion)")
            if 'run_esbmc' in result['tools_used']:
                print(f"   - esbmc_verify.c (ESBMC verification)")
                print(f"\n💡 Test ESBMC manually:")
                print(f"   esbmc esbmc_verify.c --unwind 10 --deadlock-check")

    else:
        # Run demo
        print("No file provided. Running demo test...\n")
        print("💡 To test threading deadlock detection, use: --force-deadlock\n")
        agent = EnhancedVerificationAgent(
            api_key=api_key,
            force_tools=force_tools,
            esbmc_path=args.esbmc_path
        )

        name, code = test_cases[0]
        print(f"\n{'='*80}")
        print(f"DEMO TEST: {name}")
        print(f"{'='*80}\n")

        result = agent.verify(code, max_iterations=args.max_iterations)

        print(f"\n{'='*80}")
        print("VERIFICATION SUMMARY")
        print(f"{'='*80}")
        print(f"Iterations: {result['iterations']}")
        print(f"Tools used: {', '.join(result['tools_used'])}")
        print(f"Verified: {'✅ YES' if result['verified'] else '❌ NO'}")
