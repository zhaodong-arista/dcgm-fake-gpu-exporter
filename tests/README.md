# Test Scripts

This directory contains test scripts for validating the DCGM Fake GPU Exporter functionality.

## Test Scripts

### `test-uds.sh`
**Unix Domain Socket (UDS) connectivity test**

Tests the optional UDS support for metrics delivery.

```bash
./tests/test-uds.sh
```

**What it tests:**
1. ✓ DCGM exporter is running
2. ✓ UDS is enabled (`ENABLE_UDS=true`)
3. ✓ Socket file exists (`/tmp/dcgm-metrics/metrics.sock`)
4. ✓ HTTP metrics endpoint working
5. ✓ UDS metrics endpoint working (inside container)
6. ✓ HTTP vs UDS comparison (same data)
7. ✓ Performance comparison

**Prerequisites:**
```bash
# Start container with UDS enabled
docker run -d --name dcgm-exporter-demo \
  -p 9400:9400 \
  -v /tmp/dcgm-metrics:/var/run/dcgm \
  -e ENABLE_UDS=true \
  -e NUM_FAKE_GPUS=4 \
  dcgm-fake-gpu-exporter:latest
```

**Expected output:**
```
🧪 Testing Native UDS Support
==========================================

1️⃣  Checking if DCGM exporter is running...
✓ DCGM exporter is running

2️⃣  Checking if UDS is enabled...
✓ UDS is enabled (ENABLE_UDS=true)

...

🎉 All tests passed!
```

**Note:** On macOS, host-side UDS access is limited due to Docker Desktop constraints. This works perfectly on Linux.

### `test-wave-updates.sh`
**Wave profile metric updates test**

Tests that the `wave` metric profile updates correctly over time.

```bash
./tests/test-wave-updates.sh
```

**What it tests:**
1. ✓ Container is running
2. ✓ Metrics endpoint responding
3. ✓ Wave profile GPU exists
4. ✓ Temperature changes over time (sine wave pattern)

**Prerequisites:**
```bash
# Start container with wave profile
docker run -d --name dcgm-exporter-demo \
  -p 9400:9400 \
  -e NUM_FAKE_GPUS=4 \
  dcgm-fake-gpu-exporter:latest
```

## Quick Test (Manual)

**1. Health check:**
```bash
curl http://localhost:9400/health
# Expected: HTTP 200 OK
```

**2. Metrics check:**
```bash
curl http://localhost:9400/metrics | grep dcgm_gpu_temp
# Expected: Temperature metrics for all GPUs
```

**3. Profile validation:**
```bash
# Check different GPU profiles
curl -s http://localhost:9400/metrics | grep "dcgm_gpu_temp{gpu=\"1\""  # static
curl -s http://localhost:9400/metrics | grep "dcgm_gpu_temp{gpu=\"3\""  # spike
curl -s http://localhost:9400/metrics | grep "dcgm_gpu_temp{gpu=\"4\""  # wave
```

## Integration Tests

**Full stack test with Grafana:**
```bash
# Start demo stack
cd deployments
docker-compose -f docker-compose-demo.yml up -d

# Wait for startup
sleep 30

# Test Prometheus scraping
curl -s http://localhost:9090/api/v1/query?query=dcgm_gpu_temp | jq .

# Test Grafana
curl -s http://localhost:3000/api/health
```

## Troubleshooting

**Test fails - Container not running:**
```bash
docker ps | grep dcgm-exporter
# If not running, start it first
```

**Test fails - Port 9400 in use:**
```bash
lsof -i :9400
# Stop conflicting process or use different port
```

**UDS test fails on macOS:**
- This is expected - macOS Docker Desktop limitation
- UDS works inside container (verified in tests)
- UDS works perfectly on Linux (production target)

## See Also

- Build: `../scripts/build-optimized.sh`
- Deploy: `../deployments/docker-compose-demo.yml`
- Docs: `../docs/`
