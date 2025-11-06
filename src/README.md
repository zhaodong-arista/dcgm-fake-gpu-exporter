# Source Code

This directory contains the core Python source code for the DCGM Fake GPU Exporter.

## Files

### `dcgm_exporter.py`
**Main HTTP exporter**
- Serves Prometheus metrics on port 9400
- Queries DCGM via `dcgmi` command
- Formats metrics in Prometheus format
- Handles `/metrics` and `/health` endpoints

### `dcgm_fake_manager.py`
**Fake GPU manager**
- Creates fake GPUs (1-16) via DCGM API
- Assigns metric profiles to each GPU
- Injects GPU attributes (UUID, model, PCI)
- Updates metrics every 30 seconds
- Manages GPU lifecycle

### `dcgm_uds_server.py`
**Unix Domain Socket server (optional)**
- Serves metrics via UDS when `ENABLE_UDS=true`
- Proxies HTTP requests to UDS socket
- Socket path: `/var/run/dcgm/metrics.sock`
- Zero-friction consumer integration

### `docker-entrypoint.sh`
**Container entrypoint script**
- Starts `nv-hostengine` (DCGM daemon)
- Initializes fake GPUs
- Optionally starts UDS server
- Launches HTTP exporter
- Manages container lifecycle

## Metric Profiles

The fake GPU manager supports 7 different metric profiles:

| Profile | Behavior |
|---------|----------|
| `static` | Constant values (baseline testing) |
| `stable` | Small random variations (±5%) |
| `spike` | Random 2x spikes |
| `wave` | Sine wave oscillation |
| `degrading` | Gradual performance loss |
| `faulty` | Random errors/NaN injection |
| `chaos` | Extreme random variations |

## Usage

These files are copied into the Docker container during build. Do not run directly on host - they require DCGM libraries and NVML injection.

**Build:** See `../scripts/build-optimized.sh`  
**Deploy:** See `../deployments/docker-compose-demo.yml`
