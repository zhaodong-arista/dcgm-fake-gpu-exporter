#!/bin/bash
# Test script to verify wave profile metrics are changing

echo "Testing DCGM Fake GPU Exporter - Wave Profile Updates"
echo "======================================================="
echo ""

CONTAINER_NAME="dcgm-wave-test"
PORT=9400

# Clean up any existing container
docker rm -f $CONTAINER_NAME 2>/dev/null

# Start container with wave profile and faster updates
echo "Starting container with wave profile (10s update interval)..."
docker run -d \
  --name $CONTAINER_NAME \
  -p $PORT:9400 \
  -e NUM_FAKE_GPUS=4 \
  -e METRIC_PROFILE=wave \
  -e METRIC_UPDATE_INTERVAL=10 \
  ghcr.io/saiakhil2012/dcgm-fake-gpu-exporter:latest

echo "Waiting for container to start..."
sleep 15

echo ""
echo "Collecting 5 samples (10 seconds apart)..."
echo "==========================================="

for i in {1..5}; do
  echo ""
  echo "Sample $i ($(date +%H:%M:%S)):"
  echo "----------------------------"
  curl -s http://localhost:$PORT/metrics | grep "dcgm_gpu_temp{gpu=\"1\"" 
  curl -s http://localhost:$PORT/metrics | grep "dcgm_gpu_utilization{gpu=\"1\""
  curl -s http://localhost:$PORT/metrics | grep "dcgm_power_usage{gpu=\"1\""
  
  if [ $i -lt 5 ]; then
    echo "Waiting 10 seconds for next update..."
    sleep 10
  fi
done

echo ""
echo "==========================================="
echo "Test complete!"
echo ""
echo "Check if values changed between samples."
echo "For wave profile, you should see values oscillate."
echo ""
echo "Container logs:"
docker logs $CONTAINER_NAME | tail -20

echo ""
echo "To stop: docker rm -f $CONTAINER_NAME"
