#!/bin/bash
# ESBMC with Colima Setup Script
set -e
echo "🚀 Setting up ESBMC with Colima..."

# Check if Homebrew is installed
if ! command -v brew &> /dev/null; then
    echo "❌ Homebrew not found. Please install Homebrew first:"
    echo "   /bin/bash -c \"\$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)\""
    exit 1
fi

# Install Colima and Docker CLI if not already installed
echo "📦 Installing Colima and Docker CLI..."
brew install colima docker docker-compose qemu lima-additional-guestagents docker-buildx

# Fix Docker Buildx Configuration
echo "🔧 Configuring Docker Buildx..."
mkdir -p ~/.docker
cat > ~/.docker/config.json << EOF
{
  "cliPluginsExtraDirs": [
    "/opt/homebrew/lib/docker/cli-plugins"
  ]
}
EOF

# Get host CPU count and RAM, set to max CPU and configurable RAM
HOST_CPUS=$(sysctl -n hw.ncpu)
HOST_RAM_GB=$(echo "$(sysctl -n hw.memsize) / 1024 / 1024 / 1024" | bc)
COLIMA_CPUS=$HOST_CPUS
# Use 75% of RAM for more aggressive allocation, or change to 100% if desired
COLIMA_MEMORY=$(echo "$HOST_RAM_GB * 3 / 4" | bc)  # 75% of total RAM
# For 100% use: COLIMA_MEMORY=$HOST_RAM_GB

echo "🖥️  Host has $HOST_CPUS CPUs and ${HOST_RAM_GB}GB RAM"
echo "🔧 Allocating $COLIMA_CPUS CPUs and ${COLIMA_MEMORY}GB RAM to Colima ($(echo "scale=1; $COLIMA_MEMORY * 100 / $HOST_RAM_GB" | bc)% of total)"

# Start Colima if not already running
if ! colima status &> /dev/null; then
    echo "🔧 Starting Colima with max resources..."
    colima start --cpu $COLIMA_CPUS --memory $COLIMA_MEMORY --disk 50
else
    echo "✅ Colima is already running"
    echo "📊 Current Colima status:"
    colima status
fi

# Set Docker context to use Colima
echo "🔗 Setting Docker context to Colima..."
export DOCKER_HOST="unix://$HOME/.colima/default/docker.sock"
docker context use colima 2>/dev/null || docker context create colima --docker "host=unix://$HOME/.colima/default/docker.sock" && docker context use colima

# Verify buildx works, download as fallback if needed
if ! docker buildx version &> /dev/null; then
    echo "🔧 Docker Buildx not working, downloading fallback..."
    mkdir -p ~/.docker/cli-plugins
    curl -L "https://github.com/docker/buildx/releases/latest/download/buildx-v0.11.2.darwin-amd64" -o ~/.docker/cli-plugins/docker-buildx
    chmod +x ~/.docker/cli-plugins/docker-buildx
fi

# Build using docker-compose
echo "🏗️ Building ESBMC with docker-compose..."
docker-compose build

echo "🎉 Setup complete!"
echo ""
echo "To check CPU allocation inside container:"
echo "  docker-compose exec esbmc nproc"
echo ""
echo "To use ESBMC with docker-compose:"
echo "  docker-compose up -d    # Start the container"
echo "  docker-compose exec esbmc bash    # Enter the container"
echo ""
echo "Or use docker directly:"
echo "  docker run -it --rm -v \$(pwd):/workspace -w /workspace esbmc_esbmc"
echo ""
echo "To test ESBMC and Boolector inside the container:"
echo "  esbmc --version"
echo "  boolector --version"
