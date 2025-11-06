# Quick Command Reference

Quick reference for common commands. **Most users only need the [Consuming](#-consuming-metrics) section!**

## 📡 Consuming Metrics (Primary Use Case)

> **This is what most users need** - consume metrics from the exporter.

### HTTP/REST (Default - Recommended)

```bash
# Start exporter
docker run -d \
  --name dcgm-exporter \
  -p 9400:9400 \
  -e NUM_FAKE_GPUS=4 \
  ghcr.io/saiakhil2012/dcgm-fake-gpu-exporter:latest

# Consume metrics
curl http://localhost:9400/metrics

# With Prometheus
# Add to prometheus.yml:
scrape_configs:
  - job_name: 'dcgm'
    static_configs:
      - targets: ['localhost:9400']
```

### Unix Domain Socket (Optional - Low Latency)

```bash
# Start with UDS enabled
docker run -d \
  --name dcgm-exporter \
  -p 9400:9400 \
  -v /tmp/dcgm-metrics:/var/run/dcgm \
  -e NUM_FAKE_GPUS=4 \
  -e ENABLE_UDS=true \
  ghcr.io/saiakhil2012/dcgm-fake-gpu-exporter:latest

# Consume via UDS (from host)
# Python:
import socket
sock = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
sock.connect('/tmp/dcgm-metrics/metrics.sock')
sock.sendall(b'GET /metrics HTTP/1.1\r\nHost: localhost\r\n\r\n')
data = sock.recv(65536)
print(data.decode('utf-8'))
```

### With Docker Compose

```yaml
# docker-compose.yml
services:
  dcgm-exporter:
    image: ghcr.io/saiakhil2012/dcgm-fake-gpu-exporter:latest
    ports:
      - "9400:9400"
    environment:
      - NUM_FAKE_GPUS=4
      - METRIC_PROFILE=stable
    restart: unless-stopped

  prometheus:
    image: prom/prometheus:latest
    ports:
      - "9090:9090"
    # ... prometheus config
```

---

## 🚀 Quick Start (Demo)

```bash
# 1. Clone repository
git clone https://github.com/saiakhil2012/dcgm-fake-gpu-exporter.git
cd dcgm-fake-gpu-exporter

# 2. Build image
./scripts/build-optimized.sh

# 3. Run demo with Grafana
cd deployments
docker-compose -f docker-compose-demo.yml up -d

# 4. Open Grafana (wait 30 seconds first)
open http://localhost:3000
# Login: admin/admin
```

## 📁 Important Directory Locations

After repository reorganization, files are organized as follows:

| What | Location | Usage |
|------|----------|-------|
| **Scripts** | `./scripts/` | `./scripts/build-optimized.sh` |
| **Deployments** | `./deployments/` | `cd deployments && docker-compose up -d` |
| **Tests** | `./tests/` | `./tests/test-uds.sh` |
| **Source Code** | `./src/` | `vim src/dcgm_exporter.py` |
| **Dockerfiles** | `./docker/` | Listed in `docker/README.md` |
| **Documentation** | `./docs/` | See `docs/ARCHITECTURE.md` |

## 🔨 Building

```bash
# Recommended: Optimized build (2.5GB → 6GB image)
./scripts/build-optimized.sh

# Auto-detect best method
./scripts/build-smart.sh

# From existing image (no binaries needed)
./scripts/build-smart.sh --from-image

# From DCGM binaries
./scripts/build-smart.sh --from-binaries
```

## 🚢 Deploying

```bash
# All deployment commands require cd to deployments/ directory
cd deployments

# Basic deployment
docker-compose up -d

# Demo with Grafana + Prometheus + Alerting (⭐ Recommended)
docker-compose -f docker-compose-demo.yml up -d

# With OpenTelemetry
docker-compose -f docker-compose-otel.yml up -d

# With Prometheus
docker-compose --profile with-prometheus up -d

# Stop
docker-compose down
```

## 🧪 Testing

```bash
# Test UDS connectivity
./tests/test-uds.sh

# Test wave profile updates
./tests/test-wave-updates.sh

# Run all tests
for test in tests/test-*.sh; do bash "$test"; done
```

## ⚡ Makefile Shortcuts

Convenience commands that handle directory navigation for you:

```bash
make build   # Build optimized image
make up      # Start deployment
make down    # Stop deployment
make logs    # View logs
make clean   # Clean up containers and volumes
```

## 📖 Documentation

- **Quick Start**: `docs/QUICKSTART.md`
- **Architecture**: `docs/ARCHITECTURE.md`
- **Deployment**: `docs/DEPLOYMENT.md`
- **UDS Support**: `docs/UDS_SUPPORT.md`
- **Build Guide**: `scripts/README.md`
- **Test Guide**: `tests/README.md`

## 🔧 Common Tasks

### View Metrics
```bash
curl http://localhost:9400/metrics
```

### Check Health
```bash
curl http://localhost:9400/health
```

### View Logs
```bash
cd deployments
docker-compose logs -f dcgm-exporter
```

### Restart Services
```bash
cd deployments
docker-compose restart
```

### Rebuild and Restart
```bash
./scripts/build-optimized.sh
cd deployments
docker-compose down
docker-compose up -d
```

## ❓ Common Errors

### "docker-compose-demo.yml: no such file"
**Solution:** Add `cd deployments` before docker-compose commands:
```bash
cd deployments
docker-compose -f docker-compose-demo.yml up -d
```

### "build.sh: not found"
**Solution:** Scripts are now in `scripts/` directory:
```bash
./scripts/build-optimized.sh
```

### "test-uds.sh: not found"
**Solution:** Tests are now in `tests/` directory:
```bash
./tests/test-uds.sh
```

## 📋 Full Workflow Example

```bash
# 1. Clone and navigate
git clone https://github.com/saiakhil2012/dcgm-fake-gpu-exporter.git
cd dcgm-fake-gpu-exporter

# 2. Build
./scripts/build-optimized.sh

# 3. Deploy demo stack
cd deployments
docker-compose -f docker-compose-demo.yml up -d

# 4. Wait for startup
sleep 30

# 5. Test
cd ..
./tests/test-uds.sh
curl http://localhost:9400/metrics | head -20

# 6. Open Grafana
open http://localhost:3000
# Login: admin/admin

# 7. View logs (in another terminal)
cd deployments
docker-compose logs -f

# 8. Stop when done
docker-compose down
```

---

**💡 Tip:** Use `make` commands to avoid remembering paths!

See full documentation in `README.md` and `docs/` directory.
