# Docker Files

This directory contains all Dockerfile variants for building the DCGM Fake GPU Exporter.

## Dockerfiles

### `Dockerfile` (Default)
**Build from DCGM binaries (full build)**
- Requires: Full DCGM build directory
- Size: ~6GB
- Use when: You have a complete DCGM build
- Command: `docker build -f docker/Dockerfile -t dcgm-fake-gpu-exporter .`

### `Dockerfile.from-binaries-optimized` ⭐ **Recommended**
**Optimized build (essential files only)**
- Requires: `DCGM_subset.tar.gz` in `artifacts/`
- Size: ~6GB (but only copies essentials)
- Use when: Normal development and deployment
- Command: See `scripts/build-optimized.sh`

### `Dockerfile.from-binaries`
**Build from pre-extracted binaries**
- Requires: DCGM binaries in specific structure
- Size: ~6GB
- Use when: Building from extracted DCGM
- Command: `docker build -f docker/Dockerfile.from-binaries -t dcgm-fake-gpu-exporter .`

### `Dockerfile.from-image`
**Build from existing image**
- Requires: Existing dcgm-fake-gpu-exporter base image
- Size: Incremental (~100MB)
- Use when: Updating code only (not DCGM binaries)
- Command: `docker build -f docker/Dockerfile.from-image -t dcgm-fake-gpu-exporter:latest .`

## Quick Start

**Recommended:** Use the optimized build script:
```bash
./scripts/build-optimized.sh
```

This will:
1. Extract DCGM binaries from `artifacts/DCGM_subset.tar.gz`
2. Copy only essential files (~100MB vs 4.7GB)
3. Build using `Dockerfile.from-binaries-optimized`
4. Tag as `dcgm-fake-gpu-exporter:latest`

## Build Context

All Dockerfiles expect to be run from the **repository root**:
```bash
cd /path/to/dcgm-fake-gpu-exporter
docker build -f docker/Dockerfile.from-binaries-optimized -t dcgm-fake-gpu-exporter .
```

The build context (`.`) must be the root so it can access:
- `src/` - Python source files
- `dcgm_optimized/` - Extracted DCGM binaries (temporary)

## Platform

Images are built for **linux/amd64** platform. On ARM Macs, Docker Desktop uses Rosetta 2 emulation.

```bash
docker build --platform linux/amd64 ...
```

## Testing

After building, test with:
```bash
docker run -d -p 9400:9400 dcgm-fake-gpu-exporter:latest
curl http://localhost:9400/metrics
```

## See Also

- Build scripts: `../scripts/`
- Deployment configs: `../deployments/`
- Source code: `../src/`
