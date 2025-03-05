#!/usr/bin/env python3
import os
import sys
import argparse
import tempfile
import subprocess
import shutil
import signal
import time
import json
import re
from pathlib import Path
from typing import Dict, List, Optional, Tuple, Set, Any
import platform

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
    trace_output = None
    functions_file = None
    program_output = None
    llm_input = None
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
    config.trace_output = os.path.join(config.temp_dir, "trace.out")
    config.functions_file = os.path.join(config.temp_dir, "functions.list")
    config.program_output = os.path.join(config.temp_dir, "program.out")
    config.llm_input = os.path.join(config.temp_dir, "llm_input.txt")
    
    c_file_name = os.path.basename(script_python).replace('.py', '.c')
    config.c_output = os.path.join(config.temp_dir, c_file_name)
    
    # Create empty files
    for file_path in [config.trace_output, config.functions_file, config.program_output, config.llm_input]:
        with open(file_path, 'w') as f:
            pass
    
    # Copy the Python script to the temp directory
    script_dest = os.path.join(config.temp_dir, os.path.basename(script_python))
    shutil.copy2(script_python, script_dest)
    
    print(f"📂 Temporary workspace: {config.temp_dir}")
    print(f"📄 Copied Python script to temporary directory")

def setup_virtual_env() -> None:
    """Set up virtual environment if available."""
    if os.path.isdir("venv"):
        # Activate venv (not directly possible in the same process, 
        # this would require subprocess execution)
        print("Virtual environment exists but can't be activated in-script.")
        print("If needed, activate it manually before running this script.")
    elif os.path.isfile("requirements.txt"):
        print("🚀 Creating virtual environment...")
        try:
            subprocess.run([sys.executable, "-m", "venv", "venv"], check=True)
            
            # Determine the pip executable path based on OS
            if platform.system() == "Windows":
                pip_path = "venv\\Scripts\\pip"
            else:
                pip_path = "venv/bin/pip"
                
            subprocess.run([pip_path, "install", "-r", "requirements.txt"], check=True)
            print("✅ Virtual environment created and dependencies installed")
        except subprocess.CalledProcessError as e:
            print(f"❌ Failed to set up virtual environment: {e}")

def extract_function_calls() -> None:
    """Extract executed functions from trace output."""
    with open(config.trace_output, 'r') as trace_file, open(config.functions_file, 'w') as functions_file:
        functions = set()
        for line in trace_file:
            if line.startswith("funcname: "):
                func_name = line.strip().replace("funcname: ", "")
                if func_name and not func_name.startswith("<") and func_name not in functions:
                    functions.add(func_name)
                    functions_file.write(f"{func_name}\n")

def create_trace_hook_script() -> str:
    """Create a sys.settrace() hook script to trace Python code execution."""
    py_script = os.path.basename(config.script_python)
    hook_script = os.path.join(config.temp_dir, "trace_hook.py")
    full_path = os.path.abspath(config.script_python)
    
    with open(hook_script, 'w') as f:
        f.write(f'''#!/usr/bin/env python3
import sys
import os
import traceback
import inspect
import linecache

# Original script path
TARGET_SCRIPT = "{full_path}"
TARGET_SCRIPT_BASENAME = "{os.path.basename(config.script_python)}"

# Track executed functions and lines
executed_functions = set()
executed_lines = set()

# Filter for library code
IGNORE_DIRS = ['/lib/python', '/site-packages/', '/dist-packages/']

# Trace function for tracking function calls and line execution
def trace_function(frame, event, arg):
    # Get code information
    code = frame.f_code
    func_name = code.co_name
    filename = code.co_filename
    lineno = frame.f_lineno
    
    # Skip library code
    if any(lib_dir in filename for lib_dir in IGNORE_DIRS):
        return trace_function
    
    # Only trace our script and directly related files
    script_dir = os.path.dirname(os.path.abspath(TARGET_SCRIPT))
    if not (filename == TARGET_SCRIPT or filename.startswith(script_dir)):
        return trace_function
    
    # Record information based on event type
    if event == 'call':
        # Skip dunder methods except main
        if func_name.startswith('__') and func_name != '__main__':
            return trace_function
            
        # Record function call if not already recorded
        if func_name not in executed_functions:
            print(f"funcname: {{func_name}}")
            executed_functions.add(func_name)
            
    elif event == 'line':
        # Record line execution
        line_key = (filename, lineno)
        if line_key not in executed_lines:
            executed_lines.add(line_key)
            
            # Get the line content
            line = linecache.getline(filename, lineno).strip()
            if line:  # Only print non-empty lines
                print(f"line: {{os.path.basename(filename)}}:{{lineno}}: {{line}}")
    
    # Continue tracing
    return trace_function

# Set up the trace function
sys.settrace(trace_function)

# Add script directory to path for imports
script_dir = os.path.dirname(os.path.abspath(TARGET_SCRIPT))
if script_dir not in sys.path:
    sys.path.insert(0, script_dir)

# Run the script
try:
    print(f"Executing {{TARGET_SCRIPT}}")
    
    # Read and compile the script
    with open(TARGET_SCRIPT, 'rb') as f:
        code = compile(f.read(), TARGET_SCRIPT, 'exec')
    
    # Execute the script
    namespace = {{
        '__file__': TARGET_SCRIPT,
        '__name__': '__main__',
    }}
    
    exec(code, namespace)
    
    print(f"Execution completed. Found {{len(executed_functions)}} executed functions and {{len(executed_lines)}} executed lines.")
    
except Exception as e:
    print(f"Error during execution: {{e}}")
    traceback.print_exc()
''')
    
    os.chmod(hook_script, 0o755)
    print(f"Created trace hook script at {hook_script}")
    return hook_script

def create_c_file_manually(py_file: str, c_file: str) -> bool:
    """Create a basic C version of the Python code with stub functions."""
    functions = []
    
    # Read detected functions
    if os.path.exists(config.functions_file):
        with open(config.functions_file, 'r') as f:
            functions = [line.strip() for line in f if line.strip() and line.strip() != "<module>"]
    
    with open(c_file, 'w') as f:
        f.write(f'''#include <stdio.h>
#include <stdlib.h>
#include <stdbool.h>
#include <assert.h>
#include <string.h>
#include <math.h>

// Converted from {os.path.basename(py_file)}

''')
        
        # Write function stubs
        for func in functions:
            f.write(f'''// Function: {func}
int {func}(int a, int b) {{
    return a + b;
}}

''')
        
        # Write main function
        f.write(f'''int main() {{
    // Main function converted from Python
    printf("Hello from C version of {os.path.basename(py_file)}\\n");
    
    // Add assertions for each detected function
''')
        
        for func in functions:
            f.write(f'    assert({func}(1, 2) == 3);\n')
        
        f.write('''    
    return 0;
}
''')
    
    debug_log(f"Created initial C file: {c_file}")
    return True

def aider_wrapper(message_file: str, output_file: str, model: str) -> bool:
    """Run aider with automatic dependency installation, preventing history files."""
    # Detect OS and package managers
    os_type = platform.system()
    has_package_managers = {
        "brew": shutil.which("brew") is not None,
        "apt-get": shutil.which("apt-get") is not None,
        "dnf": shutil.which("dnf") is not None,
        "yum": shutil.which("yum") is not None,
        "pacman": shutil.which("pacman") is not None,
        "choco": shutil.which("choco") is not None,
        "scoop": shutil.which("scoop") is not None,
        "npm": shutil.which("npm") is not None,
        "pip": shutil.which("pip") is not None or shutil.which("pip3") is not None,
        "gem": shutil.which("gem") is not None,
        "cargo": shutil.which("cargo") is not None
    }
    
    debug_log(f"Detected operating system: {os_type}")
    
    # Determine timeout command
    timeout_cmd = None
    if shutil.which("timeout"):
        timeout_cmd = "timeout"
    elif shutil.which("gtimeout"):
        timeout_cmd = "gtimeout"
    
    # Create temp directory for aider to prevent history files in current directory
    aider_temp_dir = tempfile.mkdtemp()
    original_dir = os.getcwd()
    
    try:
        # Change to temp directory for aider execution
        os.chdir(aider_temp_dir)
        
        # Run aider with timeout and without creating history files
        cmd = ["aider", "--no-git", "--no-show-model-warnings", 
              f"--model={model}", "--yes",
              f"--message-file={message_file}", f"--file={output_file}"]  # Prevent history file creation if supported
        
        if timeout_cmd:
            cmd = [timeout_cmd, "180"] + cmd
            
        process = subprocess.Popen(
            cmd, 
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
            text=True,
            bufsize=1
        )
        
        # Process output in real-time
        package_managers = {
            "brew": "brew install",
            "apt-get": "apt-get install",
            "dnf": "dnf install",
            "yum": "yum install",
            "pacman": "pacman -S",
            "choco": "choco install",
            "scoop": "scoop install",
            "npm": "npm install -g",
            "pip": "pip install",
            "gem": "gem install",
            "cargo": "cargo install"
        }
        
        detected_installations = {mgr: set() for mgr in package_managers}
        
        for line in iter(process.stdout.readline, ''):
            print(line, end='')
            
            # Look for installation commands
            for mgr, cmd_prefix in package_managers.items():
                if cmd_prefix in line:
                    # Extract package name
                    match = re.search(f"{re.escape(cmd_prefix)} ([^ ]+)", line)
                    if match and has_package_managers[mgr]:
                        package = match.group(1)
                        detected_installations[mgr].add(package)
        
        process.wait()
        
        # Install detected packages
        for mgr, packages in detected_installations.items():
            if packages:
                print(f"Detected {mgr} packages to install: {', '.join(packages)}")
                for package in packages:
                    install_package(package, mgr)
        
        return process.returncode == 0
    
    except Exception as e:
        print(f"Error running aider: {e}")
        return False
    finally:
        # Return to original directory and clean up
        os.chdir(original_dir)
        try:
            shutil.rmtree(aider_temp_dir)
        except Exception as e:
            print(f"Warning: Could not clean up temp directory: {e}")
            
        # Remove any history or parameter files that might have been created
        for file_pattern in ['.aider.chat.history.md', '--extra-params=*']:
            for file_path in Path('.').glob(file_pattern):
                try:
                    file_path.unlink()
                    print(f"Removed file: {file_path}")
                except Exception:
                    pass

def install_package(package: str, manager: str) -> bool:
    """Install a package using the appropriate package manager."""
    print(f"Installing {package} with {manager}...")
    
    try:
        if manager == "brew":
            subprocess.run(["brew", "install", package], check=True)
        elif manager == "apt-get":
            subprocess.run(["sudo", "apt-get", "install", "-y", package], check=True)
        elif manager == "dnf":
            subprocess.run(["sudo", "dnf", "install", "-y", package], check=True)
        elif manager == "yum":
            subprocess.run(["sudo", "yum", "install", "-y", package], check=True)
        elif manager == "pacman":
            subprocess.run(["sudo", "pacman", "-S", "--noconfirm", package], check=True)
        elif manager == "choco":
            subprocess.run(["choco", "install", "-y", package], check=True)
        elif manager == "scoop":
            subprocess.run(["scoop", "install", package], check=True)
        elif manager == "npm":
            subprocess.run(["npm", "install", "-g", package], check=True)
        elif manager == "pip":
            if shutil.which("pip3"):
                subprocess.run([shutil.which("pip3"), "install", package], check=True)
            else:
                subprocess.run([shutil.which("pip"), "install", package], check=True)
        elif manager == "gem":
            subprocess.run(["gem", "install", package], check=True)
        elif manager == "cargo":
            subprocess.run(["cargo", "install", package], check=True)
        else:
            print(f"Unsupported package manager: {manager}")
            return False
            
        return True
    except subprocess.CalledProcessError as e:
        print(f"Failed to install {package}: {e}")
        return False

def convert_to_c() -> bool:
    """Convert Python to C using LLM with multiple attempts."""
    input_file = config.script_python
    output_file = config.c_output
    max_attempts = 5
    attempt = 1
    success = False
    
    # Create a temporary file for the prompt
    temp_prompt = os.path.join(config.temp_dir, "prompt.txt")
    
    # Create a simple starting C file to work with
    create_c_file_manually(input_file, output_file)
    
    # Read detected functions
    functions = []
    if os.path.exists(config.functions_file):
        with open(config.functions_file, 'r') as f:
            functions = [line.strip() for line in f if line.strip()]
    
    # Read source instructions if available
    source_instructions = ""
    if os.path.exists(config.SOURCE_INSTRUCTION_FILE):
        with open(config.SOURCE_INSTRUCTION_FILE, 'r') as f:
            source_instructions = f.read()
    
    # Build message for LLM
    with open(temp_prompt, 'w') as f:
        f.write("Convert the following Python code directly to C code.\n")
        f.write("IMPORTANT: I've already created an initial C file for you to modify. DO NOT create a new file.\n")
        f.write("EDIT THE EXISTING FILE DIRECTLY.\n\n")
        f.write("The converted code should:\n")
        f.write("1. Maintain all essential logic and algorithms\n")
        f.write("2. Handle memory management appropriately\n")
        f.write("3. Use equivalent C data structures and types\n")
        f.write("4. Include necessary headers and dependencies\n")
        f.write("5. Only output proper C code that can be parsed by a C compiler\n")
        
        # Add source instructions if available
        if source_instructions:
            f.write(source_instructions + "\n")
        
        # Add list of detected functions
        f.write("\nImplement these functions identified during execution:\n")
        for func in functions:
            f.write(f"{func}\n")
        
        # Add Python code
        f.write("\n=== PYTHON CODE ===\n")
        with open(input_file, 'r') as py_file:
            f.write(py_file.read())
        
        # Add program output if available and not too large
        if os.path.exists(config.program_output) and os.path.getsize(config.program_output) > 0:
            with open(config.program_output, 'r') as out_file:
                lines = out_file.readlines()
                if len(lines) < 50:
                    f.write("\n=== PROGRAM OUTPUT (for reference) ===\n")
                    f.writelines(lines)
                else:
                    f.write("\n=== PROGRAM OUTPUT SAMPLE (for reference) ===\n")
                    f.writelines(lines[:25])
                    f.write("... (output truncated) ...\n")
        
        # Add initial C code
        f.write("\n=== INITIAL C CODE (MODIFY THIS) ===\n")
        with open(output_file, 'r') as c_file:
            f.write(c_file.read())
    
    print(f"📤 Sending code to LLM for conversion... : {temp_prompt}")

    # Prepare Docker for testing if needed
    if config.USE_DOCKER and config.CONTAINER_ID:
        # Use existing container
        subprocess.run(["docker", "exec", config.CONTAINER_ID, "mkdir", "-p", "/workspace"], check=True)
        debug_log(f"Using existing container: {config.CONTAINER_ID}")
    
    while attempt <= max_attempts and not success:
        print(f"Attempt {attempt} of {max_attempts} to generate valid C code...")

        # Run aider to modify the C file
        aider_wrapper(temp_prompt, output_file, config.LLM_MODEL)
        
        # Show the output file contents for debugging
        debug_log("C code after aider (first 20 lines):")
        with open(output_file, 'r') as f:
            for i, line in enumerate(f):
                if i < 20:
                    debug_log(line.rstrip())
                else:
                    break
        
        # Check if the generated C code is valid
        if config.USE_DOCKER:
            filename = os.path.basename(output_file)
            output_dir = os.path.dirname(output_file)

            if config.CONTAINER_ID:
                # Copy the file into an existing container
                subprocess.run(["docker", "cp", output_file, f"{config.CONTAINER_ID}:/workspace/{filename}"], check=True)
                result = subprocess.run(
                    ["docker", "exec", config.CONTAINER_ID, "esbmc", "--parse-tree-only", f"/workspace/{filename}"],
                    capture_output=True
                ).returncode
            else:
                # Use a new container for the check
                result = subprocess.run(
                    ["docker", "run", "--rm", "-v", f"{os.getcwd()}:/workspace", "-w", "/workspace", config.DOCKER_IMAGE,
                     "esbmc", "--parse-tree-only", filename],
                    capture_output=True
                ).returncode
        else:
            # Local ESBMC
            result = subprocess.run(
                ["esbmc", "--parse-tree-only", output_file],
                capture_output=True
            ).returncode
        
        if result == 0:
            print(f"✅ Successfully generated valid C code on attempt {attempt}")
            success = True
        else:
            print(f"❌ ESBMC parse tree check failed on attempt {attempt}")
            if attempt < max_attempts:
                print("Retrying with additional instructions...")
                # Add more specific instructions to fix syntax errors
                with open(temp_prompt, 'a') as f:
                    f.write("\n=== CORRECTION INSTRUCTIONS ===\n")
                    f.write("The previous code had syntax errors. Please fix the C code to make it valid.\n")
                    f.write("Ensure you include all necessary headers and that all functions are properly defined.\n")
                    f.write("Use standard C syntax and avoid any C++ features.\n")
                time.sleep(1)

        attempt += 1
    
    os.remove(temp_prompt)
    
    if success:
        print("✅ LLM conversion completed successfully.")
        return True
    else:
        print(f"❌ Failed to generate valid C code after {max_attempts} attempts.")
        return False

def run_esbmc_for_function(function_name: str) -> int:
    """Run ESBMC verification for a specific function."""
    if function_name == "<module>":
        function_name = "main"
    
    current_cmd = f"esbmc --function {function_name} \"{config.c_output}\""

    print("----------------------------------------")
    print(f"🛠️ Testing function: {function_name}")
    print("ESBMC command to be executed:")
    print(current_cmd)
    print("----------------------------------------")

    if config.USE_DOCKER:
        if config.CONTAINER_ID:
            # The file should already be in the container
            cmd = ["docker", "exec", "-w", "/workspace", config.CONTAINER_ID] + current_cmd.split()
            return subprocess.run(cmd).returncode
        else:
            cmd = ["docker", "run", "--rm", "-v", f"{os.getcwd()}:/workspace", "-w", "/workspace", 
                  config.DOCKER_IMAGE] + current_cmd.split()
            return subprocess.run(cmd).returncode
    else:
        # Run locally
        original_dir = os.getcwd()
        os.chdir(config.temp_dir)
        try:
            return subprocess.run(current_cmd, shell=True).returncode
        finally:
            os.chdir(original_dir)

def run_tracing_session() -> None:
    """Run the interactive tracing session using sys.settrace."""
    py_script = os.path.basename(config.script_python)
    
    print(f"📌 Starting tracing for {config.script_python}...")
    
    # Create trace hook script
    hook_script = create_trace_hook_script()
    
    # Run the trace script directly
    original_dir = os.getcwd()
    os.chdir(config.temp_dir)
    
    try:
        with open(config.trace_output, 'w') as trace_file:
            subprocess.run([sys.executable, "trace_hook.py"], 
                          stdout=trace_file,
                          stderr=subprocess.STDOUT,
                          check=False)
    finally:
        os.chdir(original_dir)
    
    # Extract functions from the trace output
    extract_function_calls()
    
    # Check if we have any functions
    if not os.path.getsize(config.functions_file):
        print("⚠️ No functions detected in trace.")
        print("Last 20 lines of trace output:")
        with open(config.trace_output, 'r') as f:
            lines = f.readlines()
            for line in lines[-20:]:
                print(line.strip())
    else:
        # Show detected functions
        print("Detected functions:")
        with open(config.functions_file, 'r') as f:
            print(f.read())
    
    # Extract program output (non-trace lines)
    with open(config.trace_output, 'r') as trace_file, open(config.program_output, 'w') as program_file:
        for line in trace_file:
            if not line.startswith("funcname:") and not line.startswith("line:"):
                program_file.write(line)
    
    # Show options
    print("\nOptions:")
    print("  1) Convert to C and verify with ESBMC")
    print("  2) Restart tracing")
    print("  3) Exit tracing and cleanup")
    
    option = input("Enter option (1-3): ")
    
    if option == "1":
        # Convert and verify
        if convert_to_c():
            with open(config.functions_file, 'r') as f:
                for function_name in f:
                    function_name = function_name.strip()
                    if function_name:
                        run_esbmc_for_function(function_name)
    elif option == "2":
        # Restart tracing
        run_tracing_session()
    elif option == "3":
        # Exit tracing
        print("✅ Tracing completed.")
    else:
        print("Invalid option, exiting.")

def main() -> None:
    """Main function to parse arguments and run the script."""
    parser = argparse.ArgumentParser(description="Dynamic trace and analyze Python code")
    parser.add_argument("--docker", action="store_true", help="Run ESBMC in Docker container")
    parser.add_argument("--image", help="Specify Docker image (default: esbmc)")
    parser.add_argument("--container", help="Specify existing container ID")
    parser.add_argument("--model", help="Specify LLM model")
    parser.add_argument("filename", help="Python script to analyze")
    
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
    
    # Main tracing loop
    while True:
        run_tracing_session()
        
        # Ask if tracing should be restarted
        while True:
            reply = input("\n🔄 Do you want to restart tracing? (y = Yes, n = No): ")
            if reply.lower() == 'y':
                break  # Restart loop
            elif reply.lower() == 'n':
                print("✅ Tracing completed.")
                # Clean up
                shutil.rmtree(config.temp_dir)
                sys.exit(0)
            else:
                print("⚠️ Invalid input. Please enter 'y' for Yes or 'n' for No.")

if __name__ == "__main__":
    main()