#!/usr/bin/env python3
import os
import sys
import argparse
import tempfile
import subprocess
import shutil
import signal
import time
import re
import ast
import inspect
from pathlib import Path
from typing import Dict, List, Optional, Tuple, Set, Any
import platform
import importlib.util

# Default configuration
class Config:
    USE_DOCKER = False
    DOCKER_IMAGE = "esbmc"
    LLM_MODEL = "openrouter/anthropic/claude-3.5-sonnet"
    CONTAINER_ID = ""
    SOURCE_INSTRUCTION_FILE = "prompts/python_prompt.txt"
    ESBMC_CMD = "esbmc"
    DEBUG = True
    
    # Paths
    temp_dir = None
    program_output = None
    functions_file = None
    c_output = None

config = Config()

def debug_log(message: str) -> None:
    """Log debug messages if DEBUG is enabled."""
    if config.DEBUG:
        print(f"[DEBUG] {message}")

def show_usage() -> None:
    """Display usage instructions and exit."""
    print("Usage: python dynamic_trace.py [--docker] [--image IMAGE_NAME | --container CONTAINER_ID] [--model MODEL_NAME] <filename>")
    print("Options:")
    print("  --docker              Run ESBMC in Docker container")
    print("  --image IMAGE_NAME    Specify Docker image (default: esbmc)")
    print("  --container ID        Specify existing container ID")
    print("  --model MODEL_NAME    Specify LLM model (default: openrouter/anthropic/claude-3.5-sonnet)")
    sys.exit(1)

def setup_workspace(script_python: str) -> None:
    """Create a temporary workspace and set up necessary files."""
    config.temp_dir = tempfile.mkdtemp()
    
    # Create all temporary files inside the temp directory
    config.program_output = os.path.join(config.temp_dir, "program.out")
    config.functions_file = os.path.join(config.temp_dir, "functions.list")
    
    c_file_name = os.path.basename(script_python).replace('.py', '.c')
    config.c_output = os.path.join(os.getcwd(), c_file_name)
    
    # Create empty files
    for file_path in [config.program_output, config.functions_file]:
        with open(file_path, 'w') as f:
            pass
    
    # Copy the Python script to the temp directory
    script_dest = os.path.join(config.temp_dir, os.path.basename(script_python))
    shutil.copy2(script_python, script_dest)
    
    print(f"📂 Temporary workspace: {config.temp_dir}")
    print(f"📄 Copied Python script to temporary directory")

def extract_functions_from_source(python_file: str) -> List[str]:
    """Extract function names from Python source code using AST."""
    try:
        with open(python_file, 'r') as f:
            source = f.read()
        
        tree = ast.parse(source)
        functions = []
        
        for node in ast.walk(tree):
            if isinstance(node, ast.FunctionDef):
                functions.append(node.name)
        
        return functions
    except Exception as e:
        print(f"Error extracting functions from source: {e}")
        return []

def extract_functions_from_c_file(c_file: str) -> List[str]:
    """Extract function names from C source code using regex."""
    try:
        with open(c_file, 'r') as f:
            source = f.read()
        
        # Pattern to match function definitions in C
        # This is a simplified pattern and may not catch all cases
        pattern = r'(?:int|void|char|float|double|bool|long|short|unsigned|signed|size_t|void\*)\s+([a-zA-Z_][a-zA-Z0-9_]*)\s*\([^)]*\)\s*{'
        
        matches = re.findall(pattern, source)
        
        # Also look for function prototypes
        prototype_pattern = r'(?:int|void|char|float|double|bool|long|short|unsigned|signed|size_t|void\*)\s+([a-zA-Z_][a-zA-Z0-9_]*)\s*\([^)]*\)\s*;'
        prototype_matches = re.findall(prototype_pattern, source)
        
        # Combine and deduplicate
        all_matches = list(set(matches + prototype_matches))
        
        # Check for special naming patterns like pre_down, act_up that might correspond to 'pre' and 'act'
        function_map = {}
        for match in all_matches:
            if match.startswith('pre_'):
                function_map['pre'] = match
            elif match.startswith('act_'):
                function_map['act'] = match
        
        # Add the mapped functions to the result
        for python_name, c_name in function_map.items():
            if python_name not in all_matches:
                all_matches.append(python_name)
        
        return all_matches
    except Exception as e:
        print(f"Error extracting functions from C source: {e}")
        return []

def run_program_with_output_capture(python_file: str) -> Tuple[str, List[str]]:
    """Run the Python program and capture its output until Ctrl+C is pressed."""
    print(f"🚀 Running {python_file}...")
    print("Press Ctrl+C to stop execution and proceed with conversion")
    
    # Create a tee-like setup to capture output while displaying it
    program_output_file = os.path.join(config.temp_dir, "program_output_raw.txt")
    
    # Run with both stdout and stderr captured
    process = subprocess.Popen(
        [sys.executable, python_file],
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
        bufsize=1
    )
    
    stdout_lines = []
    stderr_lines = []
    
    # Use non-blocking reads to capture both stdout and stderr
    import select
    import fcntl
    
    # Set non-blocking mode for stdout and stderr
    for pipe in [process.stdout, process.stderr]:
        fd = pipe.fileno()
        fl = fcntl.fcntl(fd, fcntl.F_GETFL)
        fcntl.fcntl(fd, fcntl.F_SETFL, fl | os.O_NONBLOCK)
    
    try:
        while process.poll() is None:
            # Wait for output on either stdout or stderr
            ready_pipes, _, _ = select.select([process.stdout, process.stderr], [], [], 0.1)
            
            for pipe in ready_pipes:
                if pipe == process.stdout:
                    try:
                        line = process.stdout.readline()
                        if line:
                            print(f"[OUT] {line}", end='')
                            stdout_lines.append(f"[OUT] {line}")
                    except IOError:
                        pass
                elif pipe == process.stderr:
                    try:
                        line = process.stderr.readline()
                        if line:
                            print(f"[ERR] {line}", end='')
                            stderr_lines.append(f"[ERR] {line}")
                    except IOError:
                        pass
    except KeyboardInterrupt:
        print("\n\n⏹️ Program execution stopped by user (Ctrl+C)")
    finally:
        if process.poll() is None:
            process.terminate()
            try:
                process.wait(timeout=2)
            except subprocess.TimeoutExpired:
                process.kill()
    
    # Drain any remaining output
    try:
        remaining_stdout, remaining_stderr = process.communicate(timeout=1)
        if remaining_stdout:
            for line in remaining_stdout.splitlines(True):
                print(f"[OUT] {line}", end='')
                stdout_lines.append(f"[OUT] {line}")
        if remaining_stderr:
            for line in remaining_stderr.splitlines(True):
                print(f"[ERR] {line}", end='')
                stderr_lines.append(f"[ERR] {line}")
    except subprocess.TimeoutExpired:
        process.kill()
        remaining_stdout, remaining_stderr = process.communicate()
    
    # Combine all output
    all_output = stdout_lines + stderr_lines
    
    # Save output to file
    with open(config.program_output, 'w') as f:
        f.writelines(all_output)
    
    # Extract functions from source
    functions = extract_functions_from_source(python_file)
    
    # Save functions to file
    with open(config.functions_file, 'w') as f:
        for func in functions:
            f.write(f"{func}\n")
    
    return ''.join(all_output), functions

def aider_wrapper(python_file: str, c_file: str, program_output: str, functions: List[str], model: str) -> bool:
    """Run aider to convert Python to C using the Python API."""
    from aider.coders import Coder
    from aider.models import Model
    from aider.io import InputOutput
    
    print(f"📤 Running aider to convert Python to C using model: {model}")
    
    try:
        # Use the copy of the Python file in the temp directory
        temp_python_file = os.path.join(config.temp_dir, os.path.basename(python_file))
        
        # Create the C file if it doesn't exist
        if not os.path.exists(c_file):
            with open(c_file, 'w') as f:
                pass
        
        # Create the aider model
        aider_model = Model(model)
        
        # Create InputOutput with yes=True to auto-confirm changes
        io = InputOutput(yes=True, pretty=True, chat_history_file=None)
        
        # Create the coder object
        coder = Coder.create(
            main_model=aider_model,
            fnames=[temp_python_file, c_file],
            io=io,
            auto_commits=False
        )
        
        # Build the conversion prompt
        prompt = "Convert this Python code to C code.\n\n"
        prompt += "The C code should:\n"
        prompt += "1. Maintain all essential logic and algorithms\n"
        prompt += "2. Handle memory management appropriately\n"
        prompt += "3. Use equivalent C data structures and types\n"
        prompt += "4. Include necessary headers and dependencies\n"
        prompt += "5. Only output proper C code that can be parsed by a C compiler\n"
        prompt += "6. Avoid using any non-standard C libraries\n"
        prompt += "7. Make sure the code is compatible with ESBMC verification\n\n"
        prompt += "IMPORTANT: Implement each function with EXACTLY the same name as in Python.\n"
        prompt += "Do not use classes or structs with methods - implement all functions at global scope.\n"
        prompt += "For example, if Python has 'def pre(self):', implement it as 'bool pre()' in C.\n\n"
        
        # Add list of functions
        prompt += "Functions to implement:\n"
        for func in functions:
            prompt += f"- {func}\n"
        
        # Add program output with better formatting
        prompt += "\n=== PROGRAM OUTPUT ===\n"
        # Format the output to make it more readable
        formatted_output = program_output.replace("[OUT] ", "").replace("[ERR] ", "ERROR: ")
        prompt += formatted_output
        
        # Add execution context information
        prompt += "\n=== EXECUTION CONTEXT ===\n"
        prompt += "This program was executed and the output above was captured.\n"
        prompt += "The execution was stopped manually with Ctrl+C.\n"
        prompt += "Please ensure the C implementation produces similar output.\n"
        
        # Add verification requirements
        prompt += "\n=== VERIFICATION REQUIREMENTS ===\n"
        prompt += "The C code will be verified with ESBMC, so please:\n"
        prompt += "1. Avoid complex pointer arithmetic\n"
        prompt += "2. Initialize all variables\n"
        prompt += "3. Avoid recursion if possible, or ensure it has a clear termination condition\n"
        prompt += "4. Use fixed-size arrays instead of dynamic memory when possible\n"
        prompt += "5. Add assertions to verify key properties (e.g., assert(result > 0))\n"
        prompt += "6. IMPORTANT: Each function must be implemented with EXACTLY the same name as in Python\n"
        prompt += "7. Do not use classes or structs with methods - implement all functions at global scope\n"
        prompt += "8. For class methods in Python, implement them as regular C functions with the same name\n"
        
        print("\n--- Aider Conversion Starting ---")
        # Run the conversion
        coder.run(prompt)
        print("--- Aider Conversion Complete ---\n")
        
        # Check if the C file is valid by trying to compile it
        compile_cmd = ["gcc", "-c", "-o", "/dev/null", c_file]
        compile_result = subprocess.run(compile_cmd, capture_output=True, text=True)
        
        if compile_result.returncode == 0:
            print("✅ C code compiles successfully")
        else:
            print("⚠️ C code has compilation errors:")
            print(compile_result.stderr)
            print("Will attempt to fix these before verification...")
            
            # Try to fix compilation errors with a second aider run
            fix_prompt = f"The C code has compilation errors. Please fix them:\n\n{compile_result.stderr}\n\nMake sure the code compiles with gcc."
            
            print("🔧 Running aider to fix compilation errors...")
            coder.run(fix_prompt)
            
            # Check if fixed
            compile_result = subprocess.run(compile_cmd, capture_output=True, text=True)
            if compile_result.returncode == 0:
                print("✅ Fixed C code compiles successfully")
            else:
                print("⚠️ C code still has compilation errors:")
                print(compile_result.stderr)
        
        return True
    
    except Exception as e:
        print(f"Error running aider: {e}")
        import traceback
        traceback.print_exc()
        return False

def run_esbmc_verification(c_file: str, functions: List[str]) -> Dict[str, bool]:
    """Run ESBMC verification on the generated C code."""
    results = {}
    
    print("\n🔍 Running ESBMC verification...")
    
    # Check if ESBMC is installed
    if shutil.which("esbmc") is None:
        print("❌ ESBMC not found in PATH. Please install ESBMC or specify its location.")
        return {}
    
    # First, extract all function names from the C file
    c_functions = extract_functions_from_c_file(c_file)
    print(f"\nDetected functions in C file: {', '.join(c_functions)}")
    
    # Add main function if not in the list
    if "main" not in functions:
        functions.append("main")
    
    # First, try to compile the C file to check for syntax errors
    compile_cmd = ["gcc", "-c", "-o", "/dev/null", c_file]
    compile_result = subprocess.run(compile_cmd, capture_output=True, text=True)
    
    if compile_result.returncode != 0:
        print("\n⚠️ C file has compilation errors:")
        print(compile_result.stderr)
        print("Attempting verification anyway...")
    
    # Verify each function that exists in the C file
    verified_functions = []
    for func in functions:
        # Check if the function exists in the C file
        c_func = func
        if func not in c_functions and func != "main":
            # Try to find a matching function with prefix
            prefix_matches = [f for f in c_functions if f.startswith(f"{func}_")]
            if prefix_matches:
                c_func = prefix_matches[0]
                print(f"\n🔍 Function '{func}' mapped to '{c_func}' in C file")
            else:
                print(f"\n⚠️ Function '{func}' not found in C file, skipping verification")
                results[func] = False
                continue
        
        verified_functions.append(func)
        print(f"\n🧪 Verifying function: {func}")
        
        # Local ESBMC with better flags
        cmd = [
            "esbmc",
            "--function", c_func,     # Use the mapped function name
            "--no-bounds-check",      # Disable array bounds checks
            "--no-pointer-check",     # Disable pointer checks
            "--no-div-by-zero-check", # Disable division by zero checks
            "--no-align-check",       # Disable memory alignment checks
            "--no-unwinding-assertions", # Don't fail loops that need more unwinding
            "--unwind", "10",         # Unwind loops up to 10 times
            c_file
        ]
        
        print(f"Running: {' '.join(cmd)}")
        result = subprocess.run(cmd, capture_output=True, text=True)
        
        # Print full output
        print("\n--- ESBMC Output ---")
        if result.stdout:
            print(result.stdout)
        if result.stderr:
            print(result.stderr)
        print("--- End ESBMC Output ---\n")
        
        # Check result
        success = "VERIFICATION SUCCESSFUL" in result.stdout
        symbol_not_found = "main symbol" in result.stderr and "not found" in result.stderr
        
        if symbol_not_found:
            print(f"⚠️ Function '{func}' not found by ESBMC")
            results[func] = False
        else:
            results[func] = success
            status = "✅ PASSED" if success else "❌ FAILED"
            print(f"Verification result for {func}: {status}")
    
    # If no functions were verified, try to verify the whole program
    if not verified_functions:
        print("\n⚠️ No functions could be verified individually, trying whole program verification")
        cmd = [
            "esbmc",
            "--no-bounds-check",
            "--no-pointer-check",
            "--no-div-by-zero-check",
            "--no-align-check",
            "--no-unwinding-assertions",
            "--unwind", "10",
            c_file
        ]
        
        print(f"Running: {' '.join(cmd)}")
        result = subprocess.run(cmd, capture_output=True, text=True)
        
        print("\n--- ESBMC Output (Whole Program) ---")
        if result.stdout:
            print(result.stdout)
        if result.stderr:
            print(result.stderr)
        print("--- End ESBMC Output ---\n")
        
        success = "VERIFICATION SUCCESSFUL" in result.stdout
        results["whole_program"] = success
        status = "✅ PASSED" if success else "❌ FAILED"
        print(f"Whole program verification result: {status}")
    
    return results

def main() -> None:
    """Main function to parse arguments and run the script."""
    parser = argparse.ArgumentParser(description="Run Python code, capture output, and convert to C")
    parser.add_argument("--docker", action="store_true", help="Run ESBMC in Docker container")
    parser.add_argument("--image", help="Specify Docker image (default: esbmc)")
    parser.add_argument("--container", help="Specify existing container ID")
    parser.add_argument("--model", help="Specify LLM model")
    parser.add_argument("filename", help="Python script to analyze")
    
    # Check if aider is installed
    try:
        importlib.util.find_spec('aider')
    except ImportError:
        print("❌ Error: aider package is not installed.")
        print("Please install it with: pip install aider-chat")
        sys.exit(1)
    
    args = parser.parse_args()
    
    # Validate file existence
    if not os.path.isfile(args.filename):
        print(f"❌ Error: Python file '{args.filename}' does not exist.")
        sys.exit(1)
    
    # Configure settings
    config.script_python = args.filename
    
    if args.docker:
        config.USE_DOCKER = True
    
    if args.image:
        config.DOCKER_IMAGE = args.image
    
    if args.container:
        config.CONTAINER_ID = args.container
    
    if args.model:
        config.LLM_MODEL = args.model
    
    # Don't allow both image and container
    if args.image and args.container:
        print("Error: Cannot use both --image and --container")
        show_usage()
    
    # Setup workspace
    setup_workspace(args.filename)
    
    # Main workflow
    while True:
        # Run the program and capture output until Ctrl+C
        program_output, functions = run_program_with_output_capture(config.script_python)
        
        print("\nDetected functions:")
        for func in functions:
            print(f"- {func}")
        
        # Ask for confirmation
        print("\nOptions:")
        print("  1) Convert to C and verify with ESBMC")
        print("  2) Run the program again")
        print("  3) Exit")
        
        option = input("Enter option (1-3): ")
        
        if option == "1":
            # Convert to C
            c_file = config.c_output
            if aider_wrapper(config.script_python, c_file, program_output, functions, config.LLM_MODEL):
                # Run ESBMC verification
                results = run_esbmc_verification(c_file, functions)
                
                # Summary
                print("\n📊 Verification Summary:")
                for func, success in results.items():
                    status = "✅ PASSED" if success else "❌ FAILED"
                    print(f"{func}: {status}")
            
            # Ask if user wants to continue
            reply = input("\n🔄 Do you want to continue? (y = Yes, n = No): ")
            if reply.lower() != 'y':
                break
                
        elif option == "2":
            # Run again
            continue
        elif option == "3":
            # Exit
            break
        else:
            print("Invalid option, please try again.")
    
    print("✅ Program completed.")
    # Clean up
    shutil.rmtree(config.temp_dir)

if __name__ == "__main__":
    main()
