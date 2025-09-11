FROM node:18-slim

## Install dependencies for ESBMC and other build tools
RUN apt-get update && apt-get install -y \
    clang-14 \
    llvm-14 \
    clang-tidy-14 \
    python-is-python3 \
    python3 \
    git \
    ccache \
    unzip \
    wget \
    curl \
    bison \
    flex \
    g++-multilib \
    linux-libc-dev \
    libboost-all-dev \
    libz3-dev \
    libclang-14-dev \
    libclang-cpp-dev \
    cmake \
    autoconf \
    automake \
    libtool \
    pkg-config \
    libgmp-dev \
    && rm -rf /var/lib/apt/lists/*

# Set working directory for builds
WORKDIR /opt

# Install Boolector
RUN git clone --depth=1 --branch=3.2.3 https://github.com/boolector/boolector && \
    cd boolector && \
    ./contrib/setup-lingeling.sh && \
    ./contrib/setup-btor2tools.sh && \
    ./configure.sh --prefix $PWD/../boolector-release && \
    cd build && \
    make -j$(nproc) && \
    make install && \
    cd .. && \
    cd ..

# Add Boolector to PATH and library path
ENV PATH="/opt/boolector-release/bin:${PATH}"
ENV LD_LIBRARY_PATH="/opt/boolector-release/lib:${LD_LIBRARY_PATH}"
ENV PKG_CONFIG_PATH="/opt/boolector-release/lib/pkgconfig:${PKG_CONFIG_PATH}"

# Clone ESBMC (separate step for potential caching)
ARG ESBMC_COMMIT=HEAD
RUN git clone https://github.com/esbmc/esbmc.git && \
    cd esbmc && \
    git checkout ${ESBMC_COMMIT}

# Configure ESBMC build (separate step)
RUN cd esbmc && \
    mkdir build && \
    cd build && \
    echo "Configuring ESBMC with Clang..." && \
    cmake .. -DENABLE_Z3=1 -DENABLE_BOOLECTOR=1 -DBoolector_DIR=/opt/boolector-release/ -DCMAKE_C_COMPILER=clang-14 -DCMAKE_CXX_COMPILER=clang++-14

# Build ESBMC (separate step)
RUN cd esbmc/build && \
    echo "Starting ESBMC build with $(nproc) CPUs..." && \
    (make -j$(($(nproc)/2)) || echo "First attempt failed, trying again..." && make -j$(($(nproc)/2)) || echo "Second attempt failed, trying single-threaded..." && make -j1)

# Install ESBMC
RUN cd /opt/esbmc/build && \
    make install

# Add ESBMC to PATH
ENV PATH="/opt/esbmc/build/src:${PATH}"

# Set working directory back to root
WORKDIR /

# Keep the container running with tail -f /dev/null
CMD ["bash", "-c", "tail -f /dev/null"]
