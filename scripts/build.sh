#!/bin/bash
# DCGM Fake GPU Exporter - Unified Build Script
# Auto-detects best build method or uses specified method

set -e

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

# Configuration
IMAGE_NAME="${IMAGE_NAME:-dcgm-fake-gpu-exporter}"
TAG="${TAG:-latest}"
FULL_IMAGE="${IMAGE_NAME}:${TAG}"
DCGM_DIR="${DCGM_DIR:-$HOME/Workspace/DCGM/_out/Linux-amd64-debug}"

# Navigate to repository root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$REPO_ROOT"

# Print header
print_header() {
    echo ""
    echo "=========================================="
    echo "DCGM Fake GPU Exporter - Build"
    echo "=========================================="
    echo ""
}

# Print help
print_help() {
    cat << EOF
Usage: $0 [METHOD] [OPTIONS]

Build Methods:
  auto              Auto-detect best method (default)
  optimized         Optimized build from tar file (recommended)
  from-binaries     Build from DCGM binaries directory
  from-image        Build from existing Docker image

Options:
  -t, --tag TAG     Docker image tag (default: latest)
  -h, --help        Show this help message

Environment Variables:
  DCGM_DIR          Path to DCGM binaries (default: ~/Workspace/DCGM/_out/Linux-amd64-debug)
  IMAGE_NAME        Docker image name (default: dcgm-fake-gpu-exporter)

Examples:
  $0                              # Auto-detect and build
  $0 optimized                    # Optimized build (recommended)
  $0 from-image                   # Build from existing image
  $0 from-binaries                # Build from DCGM binaries
  $0 optimized -t v2.0            # Build with custom tag

For most users:
  $0 optimized                    # Best option if you have artifacts/DCGM_subset.tar.gz

EOF
    exit 0
}

# Check if binaries exist
check_binaries() {
    if [ -d "$DCGM_DIR/bin" ] && \
       [ -f "$DCGM_DIR/bin/nv-hostengine" ] && \
       [ -d "$DCGM_DIR/lib" ] && \
       [ -d "$DCGM_DIR/share/dcgm_tests" ]; then
        return 0
    fi
    return 1
}

# Check if tar file exists
check_tarfile() {
    [ -f "artifacts/DCGM_subset.tar.gz" ]
}

# Check if base image exists
check_base_image() {
    docker image inspect "${IMAGE_NAME}:latest" &> /dev/null || \
    docker image inspect "${IMAGE_NAME}:base" &> /dev/null || \
    docker image inspect "${IMAGE_NAME}:v1" &> /dev/null
}

# Auto-detect best build method
auto_detect() {
    echo -e "${BLUE}Auto-detecting build method...${NC}"
    echo ""
    
    local has_tarfile=false
    local has_binaries=false
    local has_image=false
    
    if check_tarfile; then
        echo -e "${GREEN}✓ DCGM tar file found${NC}"
        has_tarfile=true
    else
        echo -e "${YELLOW}✗ DCGM tar file not found (artifacts/DCGM_subset.tar.gz)${NC}"
    fi
    
    if check_binaries; then
        echo -e "${GREEN}✓ DCGM binaries found${NC}"
        has_binaries=true
    else
        echo -e "${YELLOW}✗ DCGM binaries not found${NC}"
    fi
    
    if check_base_image; then
        echo -e "${GREEN}✓ Base image found${NC}"
        has_image=true
    else
        echo -e "${YELLOW}✗ Base image not found${NC}"
    fi
    
    echo ""
    
    # Priority: image > tarfile > binaries (fastest to slowest)
    if [ "$has_image" = true ]; then
        echo -e "${GREEN}→ Using: Build from existing image (fastest)${NC}"
        return 3
    elif [ "$has_tarfile" = true ]; then
        echo -e "${GREEN}→ Using: Optimized build (from tar file)${NC}"
        return 1
    elif [ "$has_binaries" = true ]; then
        echo -e "${GREEN}→ Using: Build from binaries${NC}"
        return 2
    else
        echo -e "${RED}✗ Cannot build: No source found${NC}"
        echo ""
        echo "Please provide one of:"
        echo "  1. Pull/build a base image first (or run 'optimized' method once)"
        echo "  2. DCGM tar file at artifacts/DCGM_subset.tar.gz"
        echo "  3. Set DCGM_DIR to your DCGM binaries"
        echo ""
        echo "See README.md for instructions on obtaining DCGM binaries."
        return 0
    fi
}

# Build optimized (from tar file)
build_optimized() {
    echo ""
    echo -e "${BLUE}Building optimized image from tar file...${NC}"
    echo ""
    
    if ! check_tarfile; then
        echo -e "${RED}✗ DCGM tar file not found: artifacts/DCGM_subset.tar.gz${NC}"
        echo "See artifacts/README.md for how to obtain it."
        exit 1
    fi
    
    echo "Extracting DCGM binaries..."
    tar -xzf artifacts/DCGM_subset.tar.gz
    
    echo "Preparing optimized build context..."
    rm -rf dcgm_optimized
    mkdir -p dcgm_optimized/bin dcgm_optimized/lib dcgm_optimized/share/dcgm_tests
    
    echo "Copying essential files only..."
    # Binary
    cp DCGM/_out/Linux-amd64-debug/bin/nv-hostengine dcgm_optimized/bin/
    
    # Libraries
    cp -L DCGM/_out/Linux-amd64-debug/lib/libdcgm.so* dcgm_optimized/lib/ 2>/dev/null || true
    cp -L DCGM/_out/Linux-amd64-debug/lib/libnvml_injection.so* dcgm_optimized/lib/ 2>/dev/null || true
    cp -L DCGM/_out/Linux-amd64-debug/lib/libnvidia-ml.so* dcgm_optimized/lib/ 2>/dev/null || true
    cp -L DCGM/_out/Linux-amd64-debug/lib/libdcgmmodule*.so* dcgm_optimized/lib/ 2>/dev/null || true
    
    # Share directory
    cp -r DCGM/_out/Linux-amd64-debug/share dcgm_optimized/
    
    echo ""
    echo "Size comparison:"
    echo -n "  Original: " && du -sh DCGM/_out/Linux-amd64-debug/ | cut -f1
    echo -n "  Optimized: " && du -sh dcgm_optimized/ | cut -f1
    echo ""
    
    echo "Building Docker image..."
    docker build \
        -f docker/Dockerfile.from-binaries-optimized \
        -t "${FULL_IMAGE}" \
        --platform linux/amd64 \
        .
    
    echo "Cleaning up..."
    rm -rf dcgm_optimized DCGM
    
    echo ""
    echo -e "${GREEN}✓ Build complete!${NC}"
    echo "  Image: ${FULL_IMAGE}"
}

# Build from binaries
build_from_binaries() {
    echo ""
    echo -e "${BLUE}Building from DCGM binaries...${NC}"
    echo "DCGM Directory: $DCGM_DIR"
    echo ""
    
    if ! check_binaries; then
        echo -e "${RED}✗ DCGM binaries not found at: $DCGM_DIR${NC}"
        echo ""
        echo "Please either:"
        echo "  1. Set DCGM_DIR to your DCGM binaries directory"
        echo "  2. Use 'optimized' method with tar file instead"
        exit 1
    fi
    
    # Create symlinks
    ln -sf "$DCGM_DIR/bin" ./bin 2>/dev/null || true
    ln -sf "$DCGM_DIR/lib" ./lib 2>/dev/null || true
    ln -sf "$DCGM_DIR/share" ./share 2>/dev/null || true
    
    echo "Building Docker image..."
    docker build \
        -f docker/Dockerfile.from-binaries \
        -t "${FULL_IMAGE}" \
        --platform linux/amd64 \
        .
    
    # Clean up symlinks
    rm -f ./bin ./lib ./share
    
    echo ""
    echo -e "${GREEN}✓ Build complete!${NC}"
    echo "  Image: ${FULL_IMAGE}"
}

# Build from existing image
build_from_image() {
    echo ""
    echo -e "${BLUE}Building from existing image...${NC}"
    echo ""
    
    # Find base image
    local base_image=""
    if docker image inspect "${IMAGE_NAME}:latest" &> /dev/null; then
        base_image="${IMAGE_NAME}:latest"
    elif docker image inspect "${IMAGE_NAME}:base" &> /dev/null; then
        base_image="${IMAGE_NAME}:base"
    elif docker image inspect "${IMAGE_NAME}:v1" &> /dev/null; then
        base_image="${IMAGE_NAME}:v1"
    else
        echo -e "${RED}✗ No base image found${NC}"
        echo "Build from binaries or tar file first, or pull a base image."
        exit 1
    fi
    
    echo "Base Image: $base_image"
    echo ""
    
    docker build \
        -f docker/Dockerfile.from-image \
        -t "${FULL_IMAGE}" \
        --build-arg BASE_IMAGE="$base_image" \
        --platform linux/amd64 \
        .
    
    echo ""
    echo -e "${GREEN}✓ Build complete!${NC}"
    echo "  Image: ${FULL_IMAGE}"
    echo "  Base: $base_image"
}

# Print next steps
print_next_steps() {
    echo ""
    echo "=========================================="
    echo "Next Steps"
    echo "=========================================="
    echo ""
    echo "Run the container:"
    echo "  docker run -d -p 9400:9400 ${FULL_IMAGE}"
    echo ""
    echo "Or with docker-compose:"
    echo "  cd deployments && docker-compose up -d"
    echo ""
    echo "Test it:"
    echo "  curl http://localhost:9400/metrics"
    echo ""
}

# Parse arguments
METHOD=""
while [[ $# -gt 0 ]]; do
    case $1 in
        auto|optimized|from-binaries|from-image)
            METHOD="$1"
            shift
            ;;
        -t|--tag)
            TAG="$2"
            FULL_IMAGE="${IMAGE_NAME}:${TAG}"
            shift 2
            ;;
        -h|--help)
            print_help
            ;;
        *)
            echo "Unknown option: $1"
            echo "Use --help for usage information"
            exit 1
            ;;
    esac
done

# Default to auto if no method specified
if [ -z "$METHOD" ]; then
    METHOD="auto"
fi

# Print header
print_header

# Execute build based on method
case $METHOD in
    auto)
        set +e
        auto_detect
        result=$?
        set -e
        
        case $result in
            1) build_optimized ;;
            2) build_from_binaries ;;
            3) build_from_image ;;
            *) exit 1 ;;
        esac
        ;;
    optimized)
        build_optimized
        ;;
    from-binaries)
        build_from_binaries
        ;;
    from-image)
        build_from_image
        ;;
esac

# Print next steps
print_next_steps