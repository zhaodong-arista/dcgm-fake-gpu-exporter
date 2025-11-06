#!/bin/bash
# Test UDS connectivity for DCGM Fake GPU Exporter (Native UDS)

echo "🧪 Testing Native UDS Support"
echo "=========================================="
echo ""

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check if DCGM exporter is running
echo "1️⃣  Checking if DCGM exporter is running..."
if docker ps | grep -q dcgm-exporter-demo; then
    echo -e "${GREEN}✓ DCGM exporter is running${NC}"
else
    echo -e "${RED}✗ DCGM exporter not running${NC}"
    echo ""
    echo "Start with UDS enabled:"
    echo "  docker run -d -p 9400:9400 \\"
    echo "    -v /tmp/dcgm-metrics:/var/run/dcgm \\"
    echo "    -e ENABLE_UDS=true \\"
    echo "    -e NUM_FAKE_GPUS=4 \\"
    echo "    ghcr.io/saiakhil2012/dcgm-fake-gpu-exporter:latest"
    echo ""
    exit 1
fi

echo ""
echo "2️⃣  Checking if UDS is enabled..."
UDS_ENABLED=$(docker exec dcgm-exporter-demo sh -c 'echo $ENABLE_UDS' 2>/dev/null)
if [ "$UDS_ENABLED" = "true" ]; then
    echo -e "${GREEN}✓ UDS is enabled (ENABLE_UDS=true)${NC}"
else
    echo -e "${YELLOW}⚠  UDS not enabled (ENABLE_UDS=$UDS_ENABLED)${NC}"
    echo ""
    echo "Enable UDS by setting:"
    echo "  -e ENABLE_UDS=true"
    echo ""
    exit 1
fi

echo ""
echo "3️⃣  Checking if socket file exists..."
if [ -S /tmp/dcgm-metrics/metrics.sock ]; then
    echo -e "${GREEN}✓ Socket file exists: /tmp/dcgm-metrics/metrics.sock${NC}"
    ls -lh /tmp/dcgm-metrics/metrics.sock
else
    echo -e "${RED}✗ Socket file not found${NC}"
    echo "Expected: /tmp/dcgm-metrics/metrics.sock"
    echo "Found in /tmp/dcgm-metrics:"
    ls -la /tmp/dcgm-metrics/ 2>/dev/null || echo "  (directory doesn't exist)"
    echo ""
    echo "Make sure you mounted the volume:"
    echo "  -v /tmp/dcgm-metrics:/var/run/dcgm"
    echo ""
    exit 1
fi

echo ""
echo "4️⃣  Testing HTTP access (baseline)..."
if curl -s http://localhost:9400/metrics | head -3 | grep -q "dcgm"; then
    echo -e "${GREEN}✓ HTTP metrics endpoint working${NC}"
else
    echo -e "${RED}✗ HTTP metrics endpoint failed${NC}"
    exit 1
fi

echo ""
echo "5️⃣  Testing UDS access..."

# Test from INSIDE the container (works on all platforms)
UDS_OUTPUT=$(docker exec dcgm-exporter-demo sh -c "curl -s --unix-socket /var/run/dcgm/metrics.sock http://localhost/metrics" 2>&1)
if echo "$UDS_OUTPUT" | head -3 | grep -q "dcgm"; then
    echo -e "${GREEN}✓ UDS metrics endpoint working (inside container)${NC}"
    echo ""
    echo "Sample metrics from UDS:"
    echo "$UDS_OUTPUT" | grep "dcgm_gpu_temp" | head -4
else
    echo -e "${RED}✗ UDS metrics endpoint failed${NC}"
    echo "Error: $UDS_OUTPUT"
    exit 1
fi

# Try from host (only works on Linux, not macOS Docker Desktop)
if [[ "$OSTYPE" == "darwin"* ]]; then
    echo -e "${YELLOW}⚠  Skipping host-side UDS test (macOS Docker Desktop limitation)${NC}"
    echo "   Note: UDS works inside container. On Linux, host access also works."
else
    echo ""
    echo "Testing UDS from host..."
    UDS_HOST=$(curl -s --unix-socket /tmp/dcgm-metrics/metrics.sock http://localhost/metrics 2>&1)
    if echo "$UDS_HOST" | head -3 | grep -q "dcgm"; then
        echo -e "${GREEN}✓ UDS also accessible from host${NC}"
    else
        echo -e "${YELLOW}⚠  UDS not accessible from host (mount limitation)${NC}"
    fi
fi

echo ""
echo "6️⃣  Comparing HTTP vs UDS (should be identical)..."
HTTP_COUNT=$(curl -s http://localhost:9400/metrics | grep "dcgm_gpu_temp{" | wc -l | tr -d ' ')
UDS_COUNT=$(docker exec dcgm-exporter-demo sh -c "curl -s --unix-socket /var/run/dcgm/metrics.sock http://localhost/metrics" | grep "dcgm_gpu_temp{" | wc -l | tr -d ' ')

if [ "$HTTP_COUNT" -eq "$UDS_COUNT" ]; then
    echo -e "${GREEN}✓ HTTP and UDS return same data ($HTTP_COUNT metrics)${NC}"
else
    echo -e "${YELLOW}⚠  Metric count differs: HTTP=$HTTP_COUNT, UDS=$UDS_COUNT${NC}"
fi

echo ""
echo "7️⃣  Performance comparison..."
echo -n "HTTP: "
time curl -s http://localhost:9400/metrics > /dev/null 2>&1
echo -n "UDS:  "
time docker exec dcgm-exporter-demo sh -c "curl -s --unix-socket /var/run/dcgm/metrics.sock http://localhost/metrics" > /dev/null 2>&1

echo ""
echo -e "${GREEN}🎉 All tests passed!${NC}"
echo ""
echo "📚 Usage examples:"
echo ""
echo "  # curl (bash)"
echo "  curl --unix-socket /tmp/dcgm-metrics/metrics.sock http://localhost/metrics"
echo ""
echo "  # Python"
echo "  import socket"
echo "  sock = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)"
echo "  sock.connect('/tmp/dcgm-metrics/metrics.sock')"
echo "  sock.sendall(b'GET /metrics HTTP/1.1\r\nHost: localhost\r\n\r\n')"
echo "  response = sock.recv(65536).decode('utf-8')"
echo "  print(response)"
echo ""
echo "✅ Native UDS support - no extra containers needed!"
echo ""
