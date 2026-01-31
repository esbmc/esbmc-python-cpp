# Shedskin: Static Python-to-C++ Conversion

[Shedskin](https://github.com/shedskin/shedskin) is a Python-to-C++ compiler that infers types statically and emits standard C++ code. This repository provides a reproducible Docker environment that installs both Shedskin and ESBMC so you can convert and verify Python programs without any local setup.

## Prerequisites

- [Docker](https://docs.docker.com/get-docker/) installed and running

## Build the Docker image

```bash
docker build -t esbmc-shedskin .
# or via Make
make docker-build
```

The image is based on Ubuntu 22.04 and installs:
- Shedskin (latest release via pip)
- ESBMC (latest release binary from GitHub)
- All required runtime libraries (`libgc`, `libpcre3`, Boost, Z3)

## Usage

### Interactive shell

Open a shell inside the container with the repository mounted at `/workspace`:

```bash
make docker-shell
```

### Run the smoke example

This target copies the `examples/` directory into a temporary location inside the container and drops you into a shell there:

```bash
make docker-run-example
# Inside the container:
shedskin shedskin_runtime_smoke.py
make
./shedskin_runtime_smoke
```

You can replace `shedskin_runtime_smoke.py` with any Shedskin-compatible Python file from the `examples/` directory.

### Convert and verify a custom file

```bash
# Mount your file into the container and run Shedskin + ESBMC
docker run --rm -v $(pwd):/workspace -w /workspace esbmc-shedskin \
  -lc "shedskin examples/shedskin_example_simple.py && make && esbmc shedskin_example_simple"
```

## Shedskin compatibility notes

Shedskin supports a **statically-typed subset** of Python. Key restrictions:

- All variables must have a single, consistent type throughout the program.
- Dynamic features (`eval`, `exec`, arbitrary `**kwargs`) are not supported.
- Only a subset of the standard library is available (see the [Shedskin docs](https://shedskin.readthedocs.io/)).

The example files under `examples/shedskin_*.py` are written to be Shedskin-compatible and serve as a starting point.

## Rebuilding after dependency changes

Use `--no-cache` to force a full rebuild (e.g. after a new Shedskin or ESBMC release):

```bash
docker build --no-cache -t esbmc-shedskin .
```
