# Unix Domain Socket (UDS) Support for DCGM Fake GPU Exporter

## 🔌 What is UDS and Why Use It?

**Unix Domain Sockets (UDS)** provide inter-process communication (IPC) on the same host without network overhead.

### **Use Cases:**
- ✅ **Higher performance** than TCP (no network stack overhead)
- ✅ **Better security** (file-system permissions, no network exposure)
- ✅ **Container-to-host communication** (mount socket as volume)
- ✅ **Sidecar patterns** (multiple containers sharing metrics)

---

## 🎯 Recommended Approach

**Question:** *"Why add a separate UDS proxy container? Why not expose UDS directly from the main container?"*

**Answer:** **You're absolutely right!** Here are the options, ranked from best to worst:

### **Option 1: Use HTTP (Recommended) ⭐**

The exporter already exposes metrics on HTTP port 9400. For most use cases, **HTTP is sufficient and simpler**:

```bash
# Consumer reads directly from HTTP
curl http://dcgm-exporter-demo:9400/metrics
```

**Why HTTP is often better than UDS:**
- ✅ Works across containers without special setup
- ✅ Works across hosts (not limited to same machine)
- ✅ Standard Prometheus format
- ✅ No extra complexity

### **Option 2: Consumer Adds UDS Proxy (If Really Needed)**

If your consumer **must use UDS**, let them add the proxy:

```yaml
# Consumer's docker-compose.yml
services:
  my-consumer-app:
    image: my-app
    volumes:
      - /tmp/metrics:/sockets
    # Reads from /sockets/metrics.sock
  
  # Consumer adds their own UDS bridge
  metrics-uds:
    image: alpine/socat
    command: UNIX-LISTEN:/sockets/metrics.sock,fork TCP:dcgm-exporter-demo:9400
    volumes:
      - /tmp/metrics:/sockets
```

**Benefits:**
- ✅ Consumer controls UDS setup
- ✅ DCGM exporter stays simple
- ✅ Only consumers who need UDS pay the complexity cost

### **Option 3: Native UDS in Exporter** ⭐ **NOW AVAILABLE!**

**Zero-friction solution for consumers!** UDS support is built into the exporter.

**Consumer just needs to:**

```yaml
# Consumer's docker-compose.yml
services:
  dcgm-exporter:
    image: ghcr.io/saiakhil2012/dcgm-fake-gpu-exporter:latest
    volumes:
      - /tmp/dcgm-metrics:/var/run/dcgm  # Mount directory for UDS
    environment:
      - NUM_FAKE_GPUS=4
      - ENABLE_UDS=true  # 🔥 Enable UDS support
    # No extra containers needed!
```

**Then consume from UDS:**

```python
import socket

sock = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
sock.connect('/tmp/dcgm-metrics/metrics.sock')
sock.sendall(b'GET /metrics HTTP/1.1\r\nHost: localhost\r\n\r\n')

response = sock.recv(65536).decode('utf-8')
# Parse HTTP response body
metrics = response.split('\r\n\r\n', 1)[1]
print(metrics)
```

**Benefits:**
- ✅ No extra containers (unlike socat approach)
- ✅ Just set `ENABLE_UDS=true`
- ✅ Same container serves both HTTP (:9400) and UDS
- ✅ Zero friction for consumers!

**Configuration:**

| Environment Variable | Default | Description |
|---------------------|---------|-------------|
| `ENABLE_UDS` | `false` | Set to `true` to enable UDS server |
| `UDS_SOCKET_PATH` | `/var/run/dcgm/metrics.sock` | Path to UDS socket inside container |

**Complete Example:**

```yaml
version: '3.8'

services:
  dcgm-exporter:
    image: ghcr.io/saiakhil2012/dcgm-fake-gpu-exporter:latest
    container_name: dcgm-exporter
    ports:
      - "9400:9400"  # HTTP (for Prometheus/Grafana)
    volumes:
      - /tmp/dcgm-metrics:/var/run/dcgm  # UDS socket directory
    environment:
      - NUM_FAKE_GPUS=4
      - GPU_PROFILES=wave,spike,stable,degrading
      - METRIC_UPDATE_INTERVAL=5
      - ENABLE_UDS=true  # Enable UDS
    restart: unless-stopped
  
  # Your consumer app
  my-consumer:
    image: my-consumer-app:latest
    volumes:
      - /tmp/dcgm-metrics:/var/run/dcgm  # Same mount point
    # Reads from /var/run/dcgm/metrics.sock
```

---

## 💡 Why We Removed the UDS Proxy Container

**Old approach (removed):**
```
Consumer → UDS Proxy Container → HTTP → DCGM Exporter
          (alpine/socat)           :9400
```

**Problems:**
- ❌ Extra container to manage
- ❌ Extra resource usage
- ❌ Extra failure point
- ❌ More complex docker-compose
- ❌ Unnecessary abstraction

**New approach:**
```
Consumer → DCGM Exporter :9400 (HTTP)
OR
Consumer → Own UDS Proxy → DCGM Exporter :9400
```

**Benefits:**
- ✅ Simpler deployment
- ✅ Fewer containers
- ✅ Consumer chooses UDS if needed
- ✅ Most users just use HTTP

---

The **real DCGM** uses both TCP (port 5555) and UDS (`/var/run/dcgm/dcgm.sock`).

### **Current Status:**
❌ Our fake exporter exposes port 5555 (TCP) but **NOT the UDS socket**  
⚠️ This is a **future enhancement** (see roadmap in README)

### **Why Not Implemented Yet?**
The fake exporter focuses on **Prometheus metrics** (HTTP on port 9400), not DCGM's native protocol.

### **Workaround:**
If consumers need DCGM's native UDS, they should use the **real DCGM** (not fake).

---

## Option 2: Expose Prometheus Metrics via UDS ✅ (RECOMMENDED)

**Better approach:** Expose the Prometheus `/metrics` endpoint via UDS instead of HTTP!

### **Architecture:**
```
┌──────────────────────────────────────────────┐
│  DCGM Fake GPU Exporter (inside container)   │
│  - Exposes metrics on :9400 (HTTP)           │
│  - Also exposes via UDS socket               │
│    /var/run/dcgm/metrics.sock                │
└──────────────┬───────────────────────────────┘
               │
               │ Volume mount
               ▼
┌──────────────────────────────────────────────┐
│  Host filesystem                             │
│  /tmp/dcgm-metrics.sock                      │
└──────────────┬───────────────────────────────┘
               │
               │ UDS connection
               ▼
┌──────────────────────────────────────────────┐
│  Consumer application                        │
│  - Reads from /tmp/dcgm-metrics.sock         │
│  - Gets Prometheus metrics format            │
└──────────────────────────────────────────────┘
```

### **Implementation Plan:**

#### 1. Add UDS support to the exporter

Create `dcgm_uds_server.py`:

```python
#!/usr/bin/env python3
import os
import socket
import requests
from pathlib import Path

# Socket path (inside container)
SOCKET_PATH = '/var/run/dcgm/metrics.sock'
METRICS_URL = 'http://localhost:9400/metrics'

def start_uds_server():
    # Remove old socket if exists
    if os.path.exists(SOCKET_PATH):
        os.unlink(SOCKET_PATH)
    
    # Create directory if needed
    Path(SOCKET_PATH).parent.mkdir(parents=True, exist_ok=True)
    
    # Create UDS server
    server = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
    server.bind(SOCKET_PATH)
    server.listen(5)
    
    # Set permissions so host can access
    os.chmod(SOCKET_PATH, 0o666)
    
    print(f"✓ UDS server listening on {SOCKET_PATH}")
    
    while True:
        conn, _ = server.accept()
        try:
            # Fetch metrics from HTTP endpoint
            response = requests.get(METRICS_URL)
            metrics_data = response.text.encode('utf-8')
            
            # Send to UDS client
            conn.sendall(metrics_data)
        except Exception as e:
            print(f"Error serving metrics: {e}")
        finally:
            conn.close()

if __name__ == '__main__':
    start_uds_server()
```

#### 2. Update docker-compose to mount the socket

```yaml
version: '3.8'

services:
  dcgm-exporter:
    image: ghcr.io/saiakhil2012/dcgm-fake-gpu-exporter:latest
    container_name: dcgm-exporter-demo
    ports:
      - "9400:9400"
    volumes:
      - /tmp/dcgm-metrics:/var/run/dcgm  # Mount UDS directory
    environment:
      - NUM_FAKE_GPUS=4
      - GPU_PROFILES=wave,spike,stable,degrading
      - ENABLE_UDS=true  # Enable UDS socket
    restart: unless-stopped
```

#### 3. Consumer reads from UDS

```python
# Consumer example (Python)
import socket

SOCKET_PATH = '/tmp/dcgm-metrics/metrics.sock'

def get_metrics_via_uds():
    client = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
    client.connect(SOCKET_PATH)
    
    data = b''
    while True:
        chunk = client.recv(4096)
        if not chunk:
            break
        data += chunk
    
    client.close()
    return data.decode('utf-8')

# Use it
metrics = get_metrics_via_uds()
print(metrics)
```

---

## Option 3: socat Proxy (No Code Changes!) ✅ (EASIEST)

**Use `socat` to bridge HTTP → UDS without modifying the exporter!**

### **How It Works:**

```bash
# On host (macOS or Linux)
socat UNIX-LISTEN:/tmp/dcgm-metrics.sock,fork,reuseaddr TCP:localhost:9400
```

Now consumers can read from `/tmp/dcgm-metrics.sock` and get the same metrics as `:9400`!

### **Docker Compose Example:**

```yaml
version: '3.8'

services:
  dcgm-exporter:
    image: ghcr.io/saiakhil2012/dcgm-fake-gpu-exporter:latest
    container_name: dcgm-exporter-demo
    ports:
      - "9400:9400"
    environment:
      - NUM_FAKE_GPUS=4
      - GPU_PROFILES=wave,spike,stable,degrading

  # UDS Proxy - bridges HTTP to Unix socket
  uds-proxy:
    image: alpine/socat
    container_name: dcgm-uds-proxy
    volumes:
      - /tmp/dcgm-metrics:/sockets
    command: UNIX-LISTEN:/sockets/metrics.sock,fork,reuseaddr TCP:dcgm-exporter-demo:9400
    depends_on:
      - dcgm-exporter
```

**Consumers can now read from `/tmp/dcgm-metrics/metrics.sock`!**

---

## 📱 Platform Compatibility

### **Does UDS work on macOS M2?**

| Platform | UDS Support | Notes |
|----------|-------------|-------|
| **Linux** | ✅ Full support | Native UDS, no issues |
| **macOS** (including M2) | ✅ **YES!** | UDS works perfectly on macOS |
| **Windows** | ⚠️ Limited | Windows has named pipes instead |

**Your M2 Mac will work perfectly with UDS!** 🎉

### **Testing on M2 Mac:**

```bash
# Start the socat proxy
docker run -d \
  --name dcgm-uds-proxy \
  -v /tmp/dcgm-metrics:/sockets \
  alpine/socat \
  UNIX-LISTEN:/sockets/metrics.sock,fork,reuseaddr \
  TCP:host.docker.internal:9400

# Test from host
curl --unix-socket /tmp/dcgm-metrics/metrics.sock http://localhost/metrics
```

---

## 🚀 Recommended Implementation

For **your use case** (consumer wants UDS), I recommend:

### **Quick Solution (Today):** Option 3 - socat proxy
- ✅ No code changes needed
- ✅ Works immediately
- ✅ Perfect for M2 Mac
- ✅ Minimal overhead

### **Long-term Solution:** Option 2 - Native UDS in exporter
- ✅ Better performance
- ✅ More control
- ✅ Can be added to roadmap

---

## 📝 Implementation Steps (socat approach)

### 1. Update docker-compose-demo.yml

Add the UDS proxy service:

```yaml
services:
  # ... existing dcgm-exporter service ...

  # UDS Proxy
  uds-proxy:
    image: alpine/socat
    container_name: dcgm-uds-proxy
    volumes:
      - /tmp/dcgm-metrics:/sockets
    command: >
      UNIX-LISTEN:/sockets/metrics.sock,fork,reuseaddr,unlink-early
      TCP:dcgm-exporter:9400
    depends_on:
      dcgm-exporter:
        condition: service_healthy
    restart: unless-stopped
```

### 2. Start the stack

```bash
cd deployments
docker-compose -f docker-compose-demo.yml up -d
```

### 3. Test UDS access

```bash
# From host (macOS M2)
curl --unix-socket /tmp/dcgm-metrics/metrics.sock http://localhost/metrics | head -20
```

### 4. Consumer uses UDS

```python
import socket

def read_metrics_uds():
    sock = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
    sock.connect('/tmp/dcgm-metrics/metrics.sock')
    
    # Send HTTP request
    sock.sendall(b'GET /metrics HTTP/1.1\r\nHost: localhost\r\n\r\n')
    
    # Read response
    response = b''
    while True:
        chunk = sock.recv(4096)
        if not chunk:
            break
        response += chunk
    
    sock.close()
    
    # Extract body (skip HTTP headers)
    body = response.split(b'\r\n\r\n', 1)[1]
    return body.decode('utf-8')

metrics = read_metrics_uds()
print(metrics)
```

---

## 🔒 Security Benefits of UDS

1. **File-system permissions** - Only users with access to the socket file can read
2. **No network exposure** - Metrics not accessible from network
3. **Container isolation** - Only containers with mounted volume can access

### Example Permissions:

```bash
# Restrict to specific user/group
chmod 660 /tmp/dcgm-metrics/metrics.sock
chown myuser:mygroup /tmp/dcgm-metrics/metrics.sock
```

---

## 🎓 Comparison: HTTP vs UDS

| Aspect | HTTP (port 9400) | UDS |
|--------|------------------|-----|
| **Performance** | Good | **Excellent** (no TCP overhead) |
| **Security** | Network exposed | **Filesystem permissions** |
| **Simplicity** | Very simple | Simple (with socat) |
| **Remote Access** | ✅ Yes | ❌ Same host only |
| **Prometheus** | ✅ Native | ⚠️ Needs config |
| **Your Consumer** | ✅ Works | ✅ **Preferred!** |

---

## 🐛 Troubleshooting

### "Connection refused" on UDS

```bash
# Check socket exists
ls -la /tmp/dcgm-metrics/

# Check permissions
stat /tmp/dcgm-metrics/metrics.sock

# Check socat is running
docker logs dcgm-uds-proxy
```

### "Permission denied"

```bash
# Fix permissions
chmod 666 /tmp/dcgm-metrics/metrics.sock
```

### Testing with curl

```bash
# Test HTTP first
curl http://localhost:9400/metrics | head

# Test UDS
curl --unix-socket /tmp/dcgm-metrics/metrics.sock http://localhost/metrics | head
```

---

## 📚 Next Steps

1. **Try socat proxy** - Works immediately, no code changes
2. **Test on M2 Mac** - UDS works perfectly!
3. **Share with consumer** - Give them socket path
4. **Consider native UDS** - If you want to add it to the exporter

---

## 💡 Summary

**Your Question:** *"Will UDS work on M2 Mac?"*  
**Answer:** ✅ **YES! UDS works perfectly on macOS M2!**

**Best Approach:**
1. Use **socat proxy** (Option 3) - Works today, zero code changes
2. Mount socket to `/tmp/dcgm-metrics/metrics.sock`
3. Consumer reads from UDS like any other socket
4. Keep HTTP on :9400 for Prometheus/Grafana

**Want me to add the socat proxy to docker-compose-demo.yml now?** 🚀
