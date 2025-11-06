# Architecture

This document provides a comprehensive technical overview of the DCGM Fake GPU Exporter architecture.

## Table of Contents

- [System Architecture](#system-architecture)
- [Component Details](#component-details)
- [Metric Profile System](#metric-profile-system)
- [Data Flow](#data-flow)
- [Deployment Architecture](#deployment-architecture)
- [UDS Architecture](#uds-architecture)
- [Container Startup](#container-startup)

---

## System Architecture

### High-Level Overview

```
╔════════════════════════════════════════════════════════════════════════════╗
║                    DCGM Fake GPU Exporter - System Architecture            ║
╚════════════════════════════════════════════════════════════════════════════╝

                              ┌─────────────┐
                              │   Users     │
                              │  Operators  │
                              └──────┬──────┘
                                     │
                        ┌────────────┴────────────┐
                        │                         │
                   ┌────▼────┐              ┌────▼────┐
                   │ Grafana │              │ Custom  │
                   │  :3000  │              │  Apps   │
                   └────┬────┘              └────┬────┘
                        │                         │
                        │    ┌────────────┐       │
                        └───▶│ Prometheus │◀──────┘
                             │   :9090    │
                             └─────┬──────┘
                                   │ Scrape
                                   │ /metrics
╔══════════════════════════════════▼═══════════════════════════════════════╗
║                    DCGM Fake GPU Exporter Container                      ║
║                                                                          ║
║  ┌────────────────────────────────────────────────────────────────┐    ║
║  │                      Exporter Layer                            │    ║
║  │                                                                 │    ║
║  │  ┌─────────────┐  ┌─────────────┐  ┌──────────────────────┐  │    ║
║  │  │HTTP Server  │  │ UDS Server  │  │  Metrics Formatter   │  │    ║
║  │  │  :9400      │  │  (optional) │  │  (Prometheus)        │  │    ║
║  │  └──────┬──────┘  └──────┬──────┘  └──────────┬───────────┘  │    ║
║  │         │                │                     │              │    ║
║  │         └────────────────┴─────────────────────┘              │    ║
║  └────────────────────────────┬─────────────────────────────────┘    ║
║                               │                                       ║
║  ┌────────────────────────────▼─────────────────────────────────┐    ║
║  │                   DCGM Manager Layer                          │    ║
║  │                                                                │    ║
║  │  ┌──────────────────────────────────────────────────────┐    │    ║
║  │  │  dcgm_fake_manager.py                                │    │    ║
║  │  │  • Creates fake GPUs (1-16)                          │    │    ║
║  │  │  • Assigns metric profiles                           │    │    ║
║  │  │  • Updates metrics every 30s                         │    │    ║
║  │  │  • Manages GPU lifecycle                             │    │    ║
║  │  └──────────────────────┬───────────────────────────────┘    │    ║
║  └─────────────────────────┼────────────────────────────────────┘    ║
║                            │                                          ║
║  ┌─────────────────────────▼────────────────────────────────────┐    ║
║  │                   DCGM Core (nv-hostengine)                   │    ║
║  │                                                                │    ║
║  │  • Manages GPU metrics database                               │    ║
║  │  • Provides DCGM API for metric queries                       │    ║
║  │  • Handles metric storage and retrieval                       │    ║
║  └─────────────────────────┬────────────────────────────────────┘    ║
║                            │                                          ║
║  ┌─────────────────────────▼────────────────────────────────────┐    ║
║  │              NVML Injection Layer (libnvml_injection.so)      │    ║
║  │                                                                │    ║
║  │  • Intercepts NVML API calls                                  │    ║
║  │  • Returns fake GPU data                                      │    ║
║  │  • Simulates NVIDIA GPU behavior                              │    ║
║  └─────────────────────────┬────────────────────────────────────┘    ║
║                            │                                          ║
║  ┌─────────────────────────▼────────────────────────────────────┐    ║
║  │                    Fake GPU Layer                             │    ║
║  │                                                                │    ║
║  │  ╔═══╗  ╔═══╗  ╔═══╗  ╔═══╗  ╔═══╗  ╔═══╗  ╔═══╗  ╔═══╗     │    ║
║  │  ║ 1 ║  ║ 2 ║  ║ 3 ║  ║ 4 ║  ║ 5 ║  ║ 6 ║  ║...║  ║16 ║     │    ║
║  │  ╚═══╝  ╚═══╝  ╚═══╝  ╚═══╝  ╚═══╝  ╚═══╝  ╚═══╝  ╚═══╝     │    ║
║  │                                                                │    ║
║  │  Profiles: static │ stable │ spike │ wave │ degrading │       │    ║
║  │            faulty │ chaos  │                                  │    ║
║  └────────────────────────────────────────────────────────────────┘    ║
╚══════════════════════════════════════════════════════════════════════════╝
```

---

## Component Details

### 1. HTTP Server (`dcgm_exporter.py`)
**Purpose:** Expose GPU metrics in Prometheus format via HTTP

**Responsibilities:**
- Listen on port 9400
- Handle `/metrics` endpoint
- Handle `/health` endpoint
- Query DCGM via `dcgmi dmon` command
- Format output as Prometheus metrics

**Technology:**
- Python 3 `http.server`
- Subprocess for dcgmi execution
- Text parsing and formatting

**Endpoints:**
```
GET /metrics  - Prometheus metrics
GET /health   - Health check (JSON)
```

### 2. UDS Server (`dcgm_uds_server.py`)
**Purpose:** Provide Unix Domain Socket access (optional)

**Responsibilities:**
- Listen on `/var/run/dcgm/metrics.sock`
- Proxy HTTP requests to UDS
- Same metrics as HTTP endpoint
- Enable consumer-friendly integration

**Technology:**
- Python 3 `socket` module (AF_UNIX)
- HTTP request parsing
- Volume mount for host access

**Configuration:**
```bash
ENABLE_UDS=true
UDS_SOCKET_PATH=/var/run/dcgm/metrics.sock
```

### 3. DCGM Manager (`dcgm_fake_manager.py`)
**Purpose:** Create and manage fake GPUs with dynamic metrics

**Responsibilities:**
- Create 1-16 fake GPUs via DCGM API
- Inject GPU attributes (UUID, model, PCI)
- Assign metric profiles to each GPU
- Update metrics every 30 seconds
- Manage background updater thread

**Key Functions:**
```python
create_fake_gpus(count)          # Create fake GPUs
inject_gpu_attributes(gpu_id)    # Set GPU properties
inject_metrics(gpu_id, profile)  # Inject metric values
start_metric_updater()           # Background thread
```

### 4. DCGM Core (`nv-hostengine`)
**Purpose:** NVIDIA Data Center GPU Manager daemon

**Responsibilities:**
- Manage GPU metrics database
- Provide DCGM API for queries
- Store and retrieve metric values
- Handle multiple fake GPUs

**API:**
- Port 5555 (internal)
- Supports up to 16 fake GPUs
- Metric IDs: 150, 155, 203, 204, 207, 210, 252, 253, 254

### 5. NVML Injection (`libnvml_injection.so`)
**Purpose:** Simulate NVIDIA GPU behavior

**Mechanism:**
- Intercepts NVML library calls
- Returns fake GPU data
- `LD_PRELOAD` injection
- No real GPU required

**Environment:**
```bash
LD_PRELOAD=libnvml_injection.so.1
NVML_INJECTION_MODE=1
```

---

## Metric Profile System

### Profile Behavior

```
╔════════════════════════════════════════════════════════════════════════════╗
║                          Metric Profile Engine                             ║
╚════════════════════════════════════════════════════════════════════════════╝

┌──────────────────────────────────────────────────────────────────────────┐
│  Profile Assignment (at startup)                                         │
│                                                                           │
│  GPU 1 ───▶ static     │  Constant values                               │
│  GPU 2 ───▶ stable     │  Small variations (±5%)                        │
│  GPU 3 ───▶ spike      │  Random spikes (2x normal)                     │
│  GPU 4 ───▶ wave       │  Sine wave oscillation                         │
│  GPU 5 ───▶ degrading  │  Gradual performance loss                      │
│  GPU 6 ───▶ faulty     │  Random errors/NaN                             │
│  GPU 7 ───▶ chaos      │  Extreme random variations                     │
│  GPU 8+ ──▶ [repeat]   │  Cycles through profiles                       │
└──────────────────────────────────────────────────────────────────────────┘
```

### Metric Update Loop

```
┌──────────────────────────────────────────────────────────────────────────┐
│  Every 30 seconds:                                                       │
│                                                                           │
│  FOR each GPU:                                                           │
│    1. Get profile type                                                   │
│    2. Generate metrics based on profile logic                           │
│    3. Inject into DCGM                                                   │
│                                                                           │
│  Metrics Updated:                                                        │
│    • Temperature (°C)                                                    │
│    • Power Usage (W)                                                     │
│    • GPU Utilization (%)                                                 │
│    • Memory Utilization (%)                                              │
│    • SM Clock (MHz)                                                      │
│    • Memory Clock (MHz)                                                  │
│    • Framebuffer Total/Used/Free (MB)                                   │
└──────────────────────────────────────────────────────────────────────────┘
```

### Profile Formulas

| Profile | Temperature Formula | Behavior |
|---------|-------------------|----------|
| **static** | `50°C` | Constant baseline |
| **stable** | `50 + random(-2.5, 2.5)` | Small fluctuations |
| **spike** | `50` or `100` (random) | Random 2x spikes |
| **wave** | `50 + 20*sin(time/60)` | Smooth oscillation |
| **degrading** | `50 + (time * 0.5)` | Gradual increase |
| **faulty** | `50` or `NaN` (20% chance) | Random errors |
| **chaos** | `random(20, 100)` | Extreme variations |

---

## Data Flow

### HTTP Request Flow

```
╔════════════════════════════════════════════════════════════════════════════╗
║                    Metrics Request Flow (HTTP)                             ║
╚════════════════════════════════════════════════════════════════════════════╝

┌─────────┐
│ Client  │  (Prometheus, curl, etc.)
└────┬────┘
     │
     │ HTTP GET http://localhost:9400/metrics
     │
     ▼
┌─────────────────────────────────────────────────────────────────────────┐
│  dcgm_exporter.py (HTTP Server)                                         │
│                                                                          │
│  1. Receive request                                                     │
│     └─▶ Parse HTTP headers                                              │
│                                                                          │
│  2. Execute dcgmi command                                               │
│     └─▶ /usr/local/dcgm/share/dcgm_tests/apps/amd64/dcgmi dmon \       │
│         -e 150,155,203,204,207,210,252,253,254 -c 1                     │
│                                                                          │
│         │                                                                │
│         ▼                                                                │
│     ┌────────────────────────────────────────────────────┐             │
│     │  DCGM Backend (nv-hostengine)                      │             │
│     │                                                     │             │
│     │  • Queries metric database                         │             │
│     │  • Retrieves latest values for all GPUs            │             │
│     │  • Returns raw metric data                         │             │
│     └────────────────────┬───────────────────────────────┘             │
│                          │                                              │
│                          ▼                                              │
│  3. Parse dcgmi output                                                  │
│     └─▶ Extract GPU metrics from table format                           │
│                                                                          │
│  4. Format as Prometheus metrics                                        │
│     └─▶ # HELP dcgm_gpu_temp GPU temperature                            │
│         # TYPE dcgm_gpu_temp gauge                                      │
│         dcgm_gpu_temp{gpu="1",device="nvidia1"} 50.0                    │
│         dcgm_gpu_temp{gpu="2",device="nvidia2"} 56.0                    │
│         ...                                                              │
│                                                                          │
│  5. Send HTTP response                                                  │
│     └─▶ Content-Type: text/plain; version=0.0.4                         │
│         Body: Prometheus-formatted metrics                              │
└─────────────────────────┬───────────────────────────────────────────────┘
                          │
                          │ HTTP 200 OK
                          │ Content: ~2-10KB (depends on GPU count)
                          │
                          ▼
                    ┌─────────┐
                    │ Client  │
                    └─────────┘

Typical Response Time: 20-50ms
Metrics Included: 9 metric types × number of GPUs
```

---

## Deployment Architecture

### Docker Compose Demo Stack

```
╔════════════════════════════════════════════════════════════════════════════╗
║                      Docker Compose Demo Stack                             ║
╚════════════════════════════════════════════════════════════════════════════╝

                        ┌──────────────────┐
                        │  Docker Network  │
                        │   dcgm-network   │
                        └────────┬─────────┘
                                 │
         ┌───────────────────────┼───────────────────────┐
         │                       │                       │
┌────────▼─────────┐   ┌─────────▼────────┐   ┌────────▼─────────┐
│   dcgm-exporter  │   │   prometheus     │   │    grafana       │
│                  │   │                  │   │                  │
│  Port: 9400      │   │  Port: 9090      │   │  Port: 3000      │
│  Health: /health │   │                  │   │                  │
│                  │   │  Scrapes every   │   │  Queries         │
│  Fake GPUs: 4    │◀──┤  15 seconds      │◀──┤  Prometheus      │
│  Profile: static │   │                  │   │                  │
│  Update: 30s     │   │  Retention: 15d  │   │  Dashboards: 2   │
│                  │   │  Storage: 1GB    │   │  Alerts: 8       │
│                  │   │                  │   │                  │
│  Volumes:        │   │  Volumes:        │   │  Volumes:        │
│  • /var/run/dcgm │   │  • ./prometheus  │   │  • ./grafana     │
│    (UDS socket)  │   │    /data         │   │    /data         │
│                  │   │  • ./prometheus  │   │  • ./grafana     │
│                  │   │    .yml:/etc/    │   │    /provisioning │
└──────────────────┘   └──────────────────┘   └──────────────────┘
         │                                              │
         │                                              │
    Exposes:                                       Provides:
    ┌─────────────────┐                        ┌─────────────────┐
    │ HTTP: :9400     │                        │ Web UI: :3000   │
    │ /metrics        │                        │ • Default       │
    │ /health         │                        │   Dashboard     │
    │                 │                        │ • Multi-Profile │
    │ UDS (optional): │                        │   Dashboard     │
    │ /tmp/dcgm-      │                        │ • Alerts        │
    │ metrics/        │                        │                 │
    │ metrics.sock    │                        │                 │
    └─────────────────┘                        └─────────────────┘
```

---

## UDS Architecture

### Unix Domain Socket (Optional Feature)

```
╔════════════════════════════════════════════════════════════════════════════╗
║                    Unix Domain Socket Architecture                         ║
╚════════════════════════════════════════════════════════════════════════════╝

┌──────────────────────────────────────────────────────────────────────────┐
│  DCGM Exporter Container (with ENABLE_UDS=true)                          │
│                                                                           │
│  ┌─────────────────┐              ┌─────────────────┐                   │
│  │  HTTP Server    │              │  UDS Server     │                   │
│  │                 │              │                 │                   │
│  │  Port: 9400     │              │  dcgm_uds_      │                   │
│  │  Global access  │              │  server.py      │                   │
│  └────────┬────────┘              └────────┬────────┘                   │
│           │                                │                            │
│           │                                │                            │
│           │        ┌───────────────────────┘                            │
│           │        │                                                    │
│           │        ▼                                                    │
│           │   Socket: /var/run/dcgm/metrics.sock                       │
│           │        │                                                    │
│           │        │ (Volume mounted to host)                          │
│           └────────┼────────────────────────────────────────────────┐  │
│                    │                                                 │  │
│               ┌────▼─────┐                                           │  │
│               │  Metrics │ ◀─── Same data source                     │  │
│               │  Engine  │                                           │  │
│               └──────────┘                                           │  │
└──────────────────┼────────────────────────────────────────────────────┘
                   │
                   │
    ┌──────────────┼──────────────┐
    │              │              │
    ▼              ▼              ▼
┌─────────┐  ┌──────────┐  ┌───────────┐
│  HTTP   │  │   UDS    │  │  Custom   │
│ :9400   │  │  Socket  │  │   Agent   │
│         │  │          │  │           │
│ Prometh-│  │ /tmp/    │  │ (connects │
│ eus     │  │ dcgm-    │  │  via UDS) │
│         │  │ metrics/ │  │           │
└─────────┘  └──────────┘  └───────────┘

Benefits:
┌────────────────────────────────────────────────────────┐
│ ✓ Lower latency (no network stack)                    │
│ ✓ File system permissions (secure)                    │
│ ✓ No port conflicts                                   │
│ ✓ Works alongside HTTP (both enabled simultaneously)  │
│ ✓ Consumer-friendly (just set ENABLE_UDS=true)        │
└────────────────────────────────────────────────────────┘
```

---

## Container Startup

### Initialization Sequence

```
╔════════════════════════════════════════════════════════════════════════════╗
║                    Container Initialization Flow                           ║
╚════════════════════════════════════════════════════════════════════════════╝

docker run -d -p 9400:9400 -e NUM_FAKE_GPUS=4 dcgm-fake-gpu-exporter
│
└─▶ docker-entrypoint.sh
    │
    ├─▶ 1. Start nv-hostengine
    │   │   └─▶ DCGM daemon starts on port 5555
    │   │       └─▶ Wait for ready (health check)
    │   │           └─▶ ✓ DCGM ready
    │   │
    ├─▶ 2. Initialize Fake GPUs
    │   │   └─▶ python3 dcgm_fake_manager.py
    │   │       │
    │   │       ├─▶ Create GPUs (NUM_FAKE_GPUS)
    │   │       │   └─▶ ✓ Created GPUs 1-4
    │   │       │
    │   │       ├─▶ Inject GPU attributes
    │   │       │   └─▶ UUID, Model, PCI address
    │   │       │       └─▶ ✓ Attributes set
    │   │       │
    │   │       ├─▶ Assign profiles
    │   │       │   └─▶ GPU 1: static
    │   │       │   └─▶ GPU 2: stable
    │   │       │   └─▶ GPU 3: spike
    │   │       │   └─▶ GPU 4: wave
    │   │       │       └─▶ ✓ Profiles assigned
    │   │       │
    │   │       ├─▶ Inject initial metrics
    │   │       │   └─▶ ✓ Metrics injected
    │   │       │
    │   │       └─▶ Start metric updater thread
    │   │           └─▶ ✓ Updater started (30s interval)
    │   │
    ├─▶ 3. Start UDS Server (if ENABLE_UDS=true)
    │   │   └─▶ python3 dcgm_uds_server.py &
    │   │       └─▶ ✓ UDS server started (PID: 32)
    │   │           └─▶ Socket: /var/run/dcgm/metrics.sock
    │   │
    └─▶ 4. Start HTTP Exporter
        └─▶ python3 dcgm_exporter.py
            └─▶ ✓ HTTP server listening on :9400
                └─▶ Ready to serve metrics!

Total startup time: 5-10 seconds

Health Check:
┌─────────────────────────────────────────┐
│ curl http://localhost:9400/health       │
│ Response: HTTP 200 OK                   │
│ Body: {"status": "healthy"}             │
└─────────────────────────────────────────┘
```

---

## Technology Stack

### Core Technologies

| Component | Technology | Version |
|-----------|-----------|---------|
| **OS** | Ubuntu | 22.04 |
| **Python** | Python 3 | 3.10+ |
| **DCGM** | NVIDIA DCGM | 4.4.1 |
| **Container** | Docker | 20.10+ |
| **Orchestration** | Docker Compose | 2.0+ |

### Python Dependencies

```
opentelemetry-sdk      # OpenTelemetry metrics
opentelemetry-api      # OpenTelemetry API
opentelemetry-exporter-otlp  # OTLP exporter
psutil                 # System utilities
requests               # HTTP library (UDS server)
```

### DCGM Components

- `nv-hostengine` - DCGM daemon
- `dcgmi` - Command-line interface
- `libdcgm.so` - Core library
- `libnvml_injection.so` - GPU simulation
- Python bindings - DCGM API

---

## Performance Characteristics

### Resource Usage

| Metric | Value | Notes |
|--------|-------|-------|
| **Container Size** | 6.14GB | Includes full DCGM stack |
| **Memory Usage** | ~200MB | Typical with 4 GPUs |
| **CPU Usage** | <1% | Idle state |
| **Startup Time** | 5-10s | Cold start |
| **Response Time** | 20-50ms | HTTP /metrics |
| **Metric Update** | 30s | Configurable |

### Scalability

- **Max GPUs:** 16 (DCGM limitation)
- **Concurrent Requests:** Unlimited (HTTP server)
- **Metric Retention:** Handled by Prometheus
- **Network Bandwidth:** Minimal (~10KB per scrape)

---

## See Also

- [Quick Start Guide](QUICKSTART.md)
- [Deployment Guide](DEPLOYMENT.md)
- [UDS Support](UDS_SUPPORT.md)
- [Building DCGM](BUILDING_DCGM.md)
- [Source Code](../src/README.md)
