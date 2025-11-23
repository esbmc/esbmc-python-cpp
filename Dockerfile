
FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive

# Install base dependencies and Python 3
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        build-essential \
        git \
        wget \
        curl \
        python3 \
        python3-dev \
        python3-pip \
        g++ \
        flex \
        bison \
        ca-certificates \
        unzip \
        libgc-dev \
        libpcre3-dev \
    && rm -rf /var/lib/apt/lists/*

# Provide compatibility symlinks for Shedskin's expected libgctba
RUN if [ -f /usr/lib/x86_64-linux-gnu/libgccpp.so ]; then \
        ln -sf /usr/lib/x86_64-linux-gnu/libgccpp.so /usr/lib/x86_64-linux-gnu/libgctba.so; \
    fi && \
    if [ -f /usr/lib/x86_64-linux-gnu/libgccpp.a ]; then \
        ln -sf /usr/lib/x86_64-linux-gnu/libgccpp.a /usr/lib/x86_64-linux-gnu/libgctba.a; \
    fi

# Install Shedskin (latest version via pip3)
# Shedskin now works with Python 3 (versions 0.9.8+)
RUN python3 -m pip install --upgrade pip setuptools wheel && \
    SHEDSKIN_LATEST=$(curl -s https://api.github.com/repos/shedskin/shedskin/releases/latest | grep '"tag_name"' | cut -d'"' -f4) && \
    echo "Installing Shedskin version: $SHEDSKIN_LATEST" && \
    python3 -m pip install "shedskin@git+https://github.com/shedskin/shedskin.git@${SHEDSKIN_LATEST}#egg=shedskin" || \
    (echo "Warning: Shedskin git installation failed. Attempting pip fallback..." && \
     python3 -m pip install shedskin || \
     echo "Warning: Shedskin installation failed completely." && true)

WORKDIR /workspace
VOLUME ["/workspace"]

# Install additional dependencies for ESBMC
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        libboost-all-dev \
        libz3-dev \
        libc6 \
        libstdc++6 \
    && rm -rf /var/lib/apt/lists/*

# Download and install latest ESBMC release (esbmc-linux.zip)
# Always fetches the latest release from GitHub
RUN ESBMC_DOWNLOAD_URL=$(curl -s https://api.github.com/repos/esbmc/esbmc/releases/latest | \
    grep -o 'https://github.com/esbmc/esbmc/releases/download/[^"]*esbmc-linux.zip' | head -n 1) && \
    echo "Downloading ESBMC from: $ESBMC_DOWNLOAD_URL" && \
    curl -L "$ESBMC_DOWNLOAD_URL" -o esbmc-linux.zip && \
    unzip -q esbmc-linux.zip && \
    mv bin/* /usr/local/bin/ && \
    mv lib/* /usr/local/lib/ && \
    mv include/* /usr/local/include/ 2>/dev/null || true && \
    rm -rf esbmc-linux.zip bin lib include license README release-notes.txt && \
    ldconfig && \
    which esbmc && esbmc --version

ENTRYPOINT ["/bin/bash"]
