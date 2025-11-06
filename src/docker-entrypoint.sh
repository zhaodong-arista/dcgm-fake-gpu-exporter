#!/bin/bash
set -e

echo "=========================================="
echo "DCGM OTel Exporter Container"
echo "=========================================="
echo ""

# Create fake GPUs using dcgm_fake_manager.py
# This will start nv-hostengine and create the fake GPUs
echo "Initializing DCGM with fake GPUs..."
python3 /root/Workspace/DCGM/_out/Linux-amd64-debug/dcgm_fake_manager.py start &
MANAGER_PID=$!

# Wait for initialization
sleep 15

# Check if manager is still running
if ! kill -0 $MANAGER_PID 2>/dev/null; then
    echo ""
    echo "✗ Failed to initialize DCGM fake GPUs"
    echo "Check logs above for details"
    exit 1
fi

echo ""
echo "✓ DCGM fake GPUs created successfully"
echo "✓ Metric updater running in background (PID: $MANAGER_PID)"
echo ""
echo "Waiting for metrics to be fully available..."
sleep 5

# Start UDS server if enabled
if [ "${ENABLE_UDS:-false}" = "true" ]; then
    echo ""
    echo "=========================================="
    echo "Starting UDS Server"
    echo "=========================================="
    python3 /root/Workspace/DCGM/_out/Linux-amd64-debug/dcgm_uds_server.py &
    UDS_PID=$!
    echo "✓ UDS server started (PID: $UDS_PID)"
    sleep 2
fi

echo ""
echo "=========================================="
echo "Starting Exporter"
echo "=========================================="
exec /root/Workspace/DCGM/_out/Linux-amd64-debug/dcgm_exporter.py
