# Deployments

This directory contains deployment configurations for the DCGM Fake GPU Exporter.

## Docker Compose Files

### `docker-compose.yml`
**Basic deployment (exporter only)**

Minimal deployment with just the DCGM exporter.

```bash
cd deployments
docker-compose up -d
```

**Services:**
- `dcgm-exporter` - DCGM Fake GPU Exporter on port 9400

**Use for:**
- Production deployments
- Minimal resource usage
- Integration with existing Prometheus/Grafana

### `docker-compose-demo.yml` ⭐ **Recommended for Demo**
**Full-featured demo stack (HTTP + UDS + Prometheus + Grafana)**

Complete "Swiss Army Knife" demo showcasing **all capabilities**:
- ✅ HTTP/REST API metrics (port 9400)
- ✅ Unix Domain Socket (UDS) for low-latency access
- ✅ Prometheus scraping and alerts
- ✅ Grafana dashboards and visualizations
- ✅ Live UDS consumer demo

```bash
cd deployments
docker-compose -f docker-compose-demo.yml up -d
```

**Services:**
- `dcgm-exporter` - DCGM Fake GPU Exporter with HTTP (:9400) + UDS enabled
- `prometheus` - Prometheus server (:9090) - scrapes HTTP endpoint
- `grafana` - Grafana dashboards (:3000)
- `uds-consumer` - Live demo consuming metrics via Unix Domain Socket

**Features:**
- 2 Grafana dashboards (default + multi-profile)
- 8 Prometheus alert rules
- Automatic dashboard provisioning
- 7-day metric retention
- **UDS consumer** - Live demonstration of socket-based metric retrieval

**Access:**
- Grafana: http://localhost:3000 (admin/admin)
- Prometheus: http://localhost:9090
- Exporter HTTP: http://localhost:9400/metrics
- UDS logs: `docker logs -f uds-consumer-demo`

## Configuration Files

### `prometheus.yml`
**Prometheus scrape configuration**

Configures Prometheus to scrape metrics from DCGM exporter.

```yaml
scrape_configs:
  - job_name: 'dcgm-exporter'
    scrape_interval: 15s
    static_configs:
      - targets: ['dcgm-exporter:9400']
```

**Customize:**
- Scrape interval (default: 15s)
- Retention time (default: 15d)
- Alert rules

## Quick Start

### Understanding the Demo Components

The `docker-compose-demo.yml` showcases **three ways** to consume metrics:

1. **HTTP/REST** (Prometheus) - Standard Prometheus scraping
   - Prometheus scrapes `http://dcgm-exporter:9400/metrics` every 15s
   - Grafana queries Prometheus for visualization
   - Production-ready monitoring stack

2. **Unix Domain Socket** (UDS Consumer) - Low-latency local access
   - `uds-consumer` connects to `/var/run/dcgm/metrics.sock`
   - Demonstrates socket-based metric retrieval
   - Shows real-time UDS performance
   - Useful for local monitoring tools

3. **Direct HTTP** (Manual) - Ad-hoc queries
   - `curl http://localhost:9400/metrics`
   - Browser access
   - Testing and debugging

### Running the Demo

**1. Full-featured demo (HTTP + UDS + Grafana):**
```bash
cd deployments
docker-compose -f docker-compose-demo.yml up -d

# Wait for startup
sleep 30

# View the stack:
# - Grafana: http://localhost:3000 (admin/admin)
# - Prometheus: http://localhost:9090
# - HTTP metrics: http://localhost:9400/metrics

# Watch UDS consumer in action:
docker logs -f uds-consumer-demo

# You'll see live metrics being fetched via Unix Domain Socket:
# [2025-11-06 12:34:56] Fetching metrics via UDS...
# ✓ Received 142 metrics via UDS
# Sample metrics (first 5):
#   dcgm_gpu_temp{gpu="1",UUID="GPU-...",device="nvidia1"} 65.0
#   dcgm_power_usage{gpu="1",...} 180.5
# GPU temperatures:
#   dcgm_gpu_temp{gpu="1",...} 65.0
#   dcgm_gpu_temp{gpu="2",...} 72.3
```

**2. Production deployment:**
```bash
cd deployments
docker-compose up -d

# Metrics available at
curl http://localhost:9400/metrics
```

**3. Custom configuration:**
```bash
# Edit docker-compose.yml
# Customize environment variables:
# - NUM_FAKE_GPUS=8
# - METRIC_PROFILE=wave
# - ENABLE_UDS=true
```

## Environment Variables

All compose files support these environment variables:

| Variable | Default | Description |
|----------|---------|-------------|
| `NUM_FAKE_GPUS` | 4 | Number of fake GPUs (1-16) |
| `METRIC_PROFILE` | static | Default profile for all GPUs |
| `METRIC_UPDATE_INTERVAL` | 30 | Metric update interval (seconds) |
| `ENABLE_UDS` | false | Enable Unix Domain Socket |
| `UDS_SOCKET_PATH` | /var/run/dcgm/metrics.sock | UDS socket path |

**Example:**
```bash
NUM_FAKE_GPUS=8 docker-compose up -d
```

## Volume Mounts

**Prometheus data:**
```yaml
volumes:
  - ./prometheus_data:/prometheus
```

**Grafana data:**
```yaml
volumes:
  - ./grafana_data:/var/lib/grafana
```

**UDS socket (optional):**
```yaml
volumes:
  - /tmp/dcgm-metrics:/var/run/dcgm
```

## Networking

All services run on a Docker bridge network:
- Network name: `dcgm-network`
- DNS resolution: Service names (e.g., `dcgm-exporter`, `prometheus`)

## Logs

**View all logs:**
```bash
cd deployments
docker-compose logs -f
```

**View specific service:**
```bash
docker-compose logs -f dcgm-exporter
docker-compose logs -f prometheus
docker-compose logs -f grafana
```

## Cleanup

**Stop services:**
```bash
cd deployments
docker-compose down
```

**Stop and remove volumes:**
```bash
docker-compose down -v
```

## Troubleshooting

**Port already in use:**
```bash
# Check what's using the port
lsof -i :9400
lsof -i :9090
lsof -i :3000

# Edit docker-compose.yml to use different ports
ports:
  - "9401:9400"  # Use 9401 instead of 9400
```

**Grafana dashboard not showing:**
```bash
# Check Prometheus is scraping
curl http://localhost:9090/api/v1/targets

# Check datasource in Grafana
# Settings -> Data Sources -> Prometheus
```

**Container fails to start:**
```bash
# Check logs
docker-compose logs dcgm-exporter

# Check resource limits
docker stats
```

## See Also

- Build: `../scripts/build-optimized.sh`
- Test: `../tests/test-uds.sh`
- Docs: `../docs/DEPLOYMENT.md`
- Grafana dashboards: `../grafana/dashboards/`
