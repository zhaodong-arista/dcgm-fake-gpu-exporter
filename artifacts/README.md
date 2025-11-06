# Artifacts

This directory contains large binary artifacts required for building the DCGM Fake GPU Exporter.

## Contents

### `DCGM_subset.tar.gz` (gitignored)
**DCGM binaries archive**

This file contains the essential DCGM binaries extracted from a full DCGM build. It includes:
- `nv-hostengine` - DCGM daemon
- `dcgmi` - DCGM command-line tool
- DCGM libraries (libdcgm, libnvml_injection, etc.)
- Python bindings and test utilities

**Size:** ~2.5GB compressed  
**Location:** Not included in git repository (too large)  
**Required for:** `scripts/build-optimized.sh`

## Download

If you don't have this file, you need to either:

### Option 1: Use existing GHCR image
```bash
docker pull ghcr.io/saiakhil2012/dcgm-fake-gpu-exporter:latest
```

### Option 2: Build DCGM yourself
See `docs/BUILDING_DCGM.md` for instructions on building DCGM from source, then create the archive:

```bash
cd ~/Workspace/DCGM/_out/Linux-amd64-debug
tar czf dcgm-fake-gpu-exporter/artifacts/DCGM_subset.tar.gz \
  bin/ lib/ share/
```

### Option 3: Extract from existing image
```bash
# Pull existing image
docker pull ghcr.io/saiakhil2012/dcgm-fake-gpu-exporter:latest

# Start temporary container
docker run -d --name dcgm-temp ghcr.io/saiakhil2012/dcgm-fake-gpu-exporter:latest

# Copy DCGM directory
docker cp dcgm-temp:/root/Workspace/DCGM/_out/Linux-amd64-debug ./DCGM

# Create archive
tar czf artifacts/DCGM_subset.tar.gz -C DCGM .

# Cleanup
docker rm -f dcgm-temp
rm -rf DCGM
```

## Why gitignore?

The DCGM binaries archive is **~2.5GB compressed**, which is:
- Too large for GitHub (100MB limit)
- Too large for Git LFS (bandwidth costs)
- Not source code (binary artifacts)
- Platform-specific (linux/amd64)

Instead, we:
1. Include instructions to download/build
2. Distribute via Docker images (GHCR)
3. Keep in local artifacts/ for development

## Structure

When extracted, the archive contains:
```
DCGM/
├── _out/
│   └── Linux-amd64-debug/
│       ├── bin/
│       │   └── nv-hostengine
│       ├── lib/
│       │   ├── libdcgm.so*
│       │   ├── libnvml_injection.so*
│       │   ├── libnvidia-ml.so*
│       │   └── libdcgmmodule*.so*
│       └── share/
│           └── dcgm_tests/
│               ├── apps/amd64/dcgmi
│               └── (Python bindings)
```

## See Also

- Build script: `../scripts/build-optimized.sh`
- DCGM build guide: `../docs/BUILDING_DCGM.md`
- Docker images: https://github.com/saiakhil2012/dcgm-fake-gpu-exporter/pkgs/container/dcgm-fake-gpu-exporter
