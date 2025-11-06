#!/usr/bin/env python3
"""
UDS server for DCGM Fake GPU Exporter
Serves the same Prometheus metrics via Unix Domain Socket

Usage:
  Set ENABLE_UDS=true environment variable
  The server will automatically start alongside the HTTP exporter
"""

import os
import socket
import threading
import time
import sys

# Configuration
UDS_PATH = os.getenv('UDS_SOCKET_PATH', '/var/run/dcgm/metrics.sock')
METRICS_URL = f"http://localhost:{os.getenv('EXPORTER_PORT', '9400')}/metrics"
ENABLE_UDS = os.getenv('ENABLE_UDS', 'false').lower() == 'true'

# Import requests only if UDS is enabled
if ENABLE_UDS:
    try:
        import requests
    except ImportError:
        print("ERROR: requests module not found. Install with: pip3 install requests", file=sys.stderr)
        sys.exit(1)

def handle_client(client_socket):
    """Handle a single UDS client connection"""
    import requests
    
    try:
        # Fetch metrics from HTTP endpoint with retry logic
        max_retries = 10
        retry_delay = 0.5
        
        for attempt in range(max_retries):
            try:
                response = requests.get(METRICS_URL, timeout=5)
                break  # Success
            except (requests.exceptions.ConnectionError, requests.exceptions.Timeout):
                if attempt < max_retries - 1:
                    time.sleep(retry_delay)
                    retry_delay = min(retry_delay * 1.5, 5.0)
                else:
                    raise
        
        # Send HTTP-style response
        http_response = (
            f"HTTP/1.1 {response.status_code} OK\r\n"
            f"Content-Type: text/plain; version=0.0.4\r\n"
            f"Content-Length: {len(response.text)}\r\n"
            f"\r\n"
            f"{response.text}"
        )
        
        client_socket.sendall(http_response.encode('utf-8'))
        
        # Shutdown write side to signal EOF
        try:
            client_socket.shutdown(socket.SHUT_WR)
        except:
            pass
            
    except Exception as e:
        error_msg = f"HTTP/1.1 500 Internal Server Error\r\n\r\nError: {str(e)}\r\n"
        try:
            client_socket.sendall(error_msg.encode('utf-8'))
            client_socket.shutdown(socket.SHUT_WR)
        except:
            pass
    finally:
        try:
            client_socket.close()
        except:
            pass

def start_uds_server():
    """Start UDS server listening for connections"""
    # Remove old socket if exists
    if os.path.exists(UDS_PATH):
        try:
            os.unlink(UDS_PATH)
        except OSError as e:
            print(f"Warning: Could not remove old socket: {e}", file=sys.stderr)
    
    # Create directory if needed
    socket_dir = os.path.dirname(UDS_PATH)
    if socket_dir and not os.path.exists(socket_dir):
        os.makedirs(socket_dir, exist_ok=True)
    
    # Create Unix domain socket
    server = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
    server.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    
    try:
        server.bind(UDS_PATH)
        server.listen(10)
        os.chmod(UDS_PATH, 0o666)
        
        print(f"UDS server listening on {UDS_PATH}", flush=True)
        
        # Accept connections forever
        while True:
            try:
                client, _ = server.accept()
                thread = threading.Thread(target=handle_client, args=(client,), daemon=True)
                thread.start()
            except KeyboardInterrupt:
                break
            except Exception as e:
                print(f"Error accepting connection: {e}", file=sys.stderr)
                time.sleep(0.1)
                
    finally:
        try:
            server.close()
        except:
            pass
        try:
            if os.path.exists(UDS_PATH):
                os.unlink(UDS_PATH)
        except:
            pass

def main():
    if not ENABLE_UDS:
        return
    
    print(f"Starting DCGM UDS server...", flush=True)
    print(f"Socket: {UDS_PATH}", flush=True)
    
    try:
        start_uds_server()
    except KeyboardInterrupt:
        pass
    finally:
        if os.path.exists(UDS_PATH):
            try:
                os.unlink(UDS_PATH)
            except:
                pass

if __name__ == '__main__':
    main()
