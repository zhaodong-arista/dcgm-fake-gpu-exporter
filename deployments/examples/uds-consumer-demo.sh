#!/bin/bash
# UDS Consumer Demo Script
# Continuously fetches metrics via Unix Domain Socket

set -e

SOCKET_PATH="/var/run/dcgm/metrics.sock"

echo "===================================="
echo "UDS Consumer Demo - Starting..."
echo "===================================="
echo ""

# Wait for socket to be available
echo "Waiting for DCGM exporter UDS socket..."
while [ ! -S "$SOCKET_PATH" ]; do
    sleep 1
done
echo "✓ Socket found at $SOCKET_PATH"
echo ""

# Install dependencies
echo "Installing Python dependencies..."
pip install -q requests 2>/dev/null || true
echo ""

echo "===================================="
echo "Fetching metrics via UDS (every 10s)"
echo "===================================="

# Continuous monitoring loop
while true; do
    echo ""
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] Fetching metrics via UDS..."
    
    python3 - << 'PYTHON_SCRIPT'
import socket
import sys
from datetime import datetime

SOCKET_PATH = "/var/run/dcgm/metrics.sock"

try:
    # Connect to UDS
    sock = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
    sock.connect(SOCKET_PATH)
    
    # Send HTTP request
    request = b'GET /metrics HTTP/1.1\r\nHost: localhost\r\n\r\n'
    sock.sendall(request)
    
    # Receive response
    response = b''
    while True:
        chunk = sock.recv(4096)
        if not chunk:
            break
        response += chunk
    
    sock.close()
    
    # Parse response
    response_text = response.decode('utf-8')
    lines = response_text.split('\n')
    
    # Count metrics (lines with = and not comments)
    metric_lines = [line for line in lines if line.strip() and not line.startswith('#') and '=' in line]
    metric_count = len(metric_lines)
    
    # Display results
    print(f'✓ Received {metric_count} metrics via UDS')
    print('')
    print('Sample metrics (first 5):')
    for i, line in enumerate(metric_lines[:5]):
        # Truncate long lines
        display_line = line[:80] + '...' if len(line) > 80 else line
        print(f'  {display_line}')
    
    # Show some interesting metrics
    print('')
    print('GPU temperatures:')
    temp_metrics = [line for line in metric_lines if 'dcgm_gpu_temp' in line]
    for line in temp_metrics[:4]:
        print(f'  {line}')
    
except Exception as e:
    print(f'✗ Error connecting to UDS: {e}', file=sys.stderr)
    # Don't exit - just continue to next iteration
PYTHON_SCRIPT
    
    # Wait before next fetch
    sleep 10
done
