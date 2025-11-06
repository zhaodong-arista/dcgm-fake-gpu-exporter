# Build Scripts

This directory contains the unified build script for the DCGM Fake GPU Exporter.

## `build.sh` - Unified Build Script ⭐

**One script, multiple build methods** - auto-detects the best option or uses your specified method.

### Quick Start

```bash
# Auto-detect and build (recommended)
./scripts/build.sh

# Use optimized method (from tar file)
./scripts/build.sh optimized

# Build from existing image (fast)
./scripts/build.sh from-image

# Build from DCGM binaries
./scripts/build.sh from-binaries

# Custom tag
./scripts/build.sh optimized -t v2.0

# Help
./scripts/build.sh --help
```

### Build Methods

| Method | When to Use | Requirements | Build Time |
|--------|-------------|--------------|------------|
| **auto** | Let the script decide (default) | Any source available | Varies |
| **from-image** | ⭐ Fastest dev iterations | Existing Docker image | ~30 sec |
| **optimized** | First-time or full rebuild | `artifacts/DCGM_subset.tar.gz` | ~2 min |
| **from-binaries** | Custom DCGM builds | DCGM binaries at `$DCGM_DIR` | ~3 min |

### How Auto-Detection Works

The script checks in this priority order (fastest to slowest):

1. **Existing Docker image**
   - If found → uses `from-image` method
   - Looks for `dcgm-fake-gpu-exporter:latest/base/v1`
   - ⚡ **Fastest:** Only updates code, ~30 seconds
   
2. **DCGM tar file** (`artifacts/DCGM_subset.tar.gz`)
   - If found → uses `optimized` method
   - Extracts only essential files (~2.5GB → 6GB image)
   - 🔧 **Full rebuild:** Use when you need fresh binaries
   
3. **DCGM binaries** (at `$DCGM_DIR`)
   - If found → uses `from-binaries` method
   - Default location: `~/Workspace/DCGM/_out/Linux-amd64-debug`
   - 🏗️ **Custom builds:** Use for non-standard DCGM
   
4. **Nothing found** → prints helpful error with instructions

**Rationale:** Prefer speed for development (image > tar > binaries)

### Environment Variables

```bash
DCGM_DIR        # Path to DCGM binaries (default: ~/Workspace/DCGM/_out/Linux-amd64-debug)
IMAGE_NAME      # Docker image name (default: dcgm-fake-gpu-exporter)
TAG             # Image tag (default: latest)
```

### Examples

```bash
# Standard build with auto-detection
./scripts/build.sh

# Optimized build with custom DCGM location
DCGM_DIR=/custom/path ./scripts/build.sh optimized

# Build with custom image name and tag
IMAGE_NAME=my-exporter TAG=dev ./scripts/build.sh from-image

# Build and immediately run
./scripts/build.sh optimized && docker run -d -p 9400:9400 dcgm-fake-gpu-exporter:latest
```

### What Each Method Does

#### Optimized (Recommended)

**Best for:** Most users with tar file

```bash
./scripts/build.sh optimized
```

- Extracts `artifacts/DCGM_subset.tar.gz`
- Copies only essential files (reduces 2.5GB to 6GB image)
- Uses multi-stage Docker build
- Cleans up automatically
- **Result:** ~6GB optimized image

#### From Image (Fastest)

**Best for:** Development iterations, code updates

```bash
./scripts/build.sh from-image
```

- Uses existing Docker image as base
- Only updates Python code and configs
- No DCGM binaries needed
- **Result:** ~30 second build time

#### From Binaries (Initial Setup)

**Best for:** First-time builds, CI/CD

```bash
# Set DCGM location if not default
export DCGM_DIR=~/Workspace/DCGM/_out/Linux-amd64-debug

./scripts/build.sh from-binaries
```

- Uses DCGM binaries directly
- Creates symlinks to binaries
- Full reproducible build
- **Result:** Base image for other methods

## Build Output

All methods tag the image as:
```
dcgm-fake-gpu-exporter:latest
```

To push to GitHub Container Registry:
```bash
docker tag dcgm-fake-gpu-exporter:latest ghcr.io/saiakhil2012/dcgm-fake-gpu-exporter:latest
docker push ghcr.io/saiakhil2012/dcgm-fake-gpu-exporter:latest
```

## Platform

All builds target **linux/amd64** platform:
```bash
--platform linux/amd64
```

This works on ARM Macs via Rosetta 2 emulation.

## Related Documentation

- **DCGM Binaries:** See `../artifacts/README.md` for obtaining DCGM tar file
- **Building DCGM:** See `../docs/BUILDING_DCGM.md` for compiling DCGM from source
- **Dockerfiles:** See `../docker/README.md` for Dockerfile details
- **Deployment:** See `../deployments/README.md` for running the built image

## Troubleshooting

### "No source found" error

Make sure you have at least one of:
- Tar file at `artifacts/DCGM_subset.tar.gz`
- DCGM binaries at `$DCGM_DIR`
- Existing Docker image

### "DCGM binaries not found"

```bash
# Check your DCGM_DIR
ls -la ~/Workspace/DCGM/_out/Linux-amd64-debug/

# Or set custom location
export DCGM_DIR=/path/to/your/dcgm/build
./scripts/build.sh from-binaries
```

### "Base image not found"

For `from-image` method, you need an existing image:

```bash
# Build from scratch first
./scripts/build.sh optimized

# Then from-image will work
./scripts/build.sh from-image
```

### Build fails - Docker out of disk space

```bash
docker system prune -a
```

### Build slow on Mac

- This is normal - emulation overhead for linux/amd64 on ARM
- Consider building on Linux for faster builds

## Why One Script?

Previously, we had 4 separate build scripts which was confusing for users:
- ❌ `build-smart.sh` - auto-detection
- ❌ `build-optimized.sh` - optimized build
- ❌ `build-manual.sh` - manual steps
- ❌ `build.sh` - legacy build

Now we have:
- ✅ **One script** with clear options
- ✅ Auto-detection by default
- ✅ Professional public-facing interface
- ✅ Consistent behavior and error messages

## See Also

- Dockerfiles: `../docker/`
- Deployment: `../deployments/`
- Testing: `../tests/`
