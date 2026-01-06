#!/usr/bin/env python3
"""DCGM OpenTelemetry/Prometheus Exporter using dcgmi CLI"""
import os, sys, time, subprocess, re, socket
from http.server import HTTPServer, BaseHTTPRequestHandler
from threading import Thread, Lock

metrics_cache = ""
metrics_lock = Lock()
gpu_info_cache = {}
gpu_info_lock = Lock()
DCGMI_PATH = "/usr/local/dcgm/share/dcgm_tests/apps/amd64/dcgmi"

# Get hostname - prefer environment variable for Kubernetes compatibility
HOSTNAME = os.environ.get('NODE_NAME', socket.gethostname())

# Map DCGM field IDs to metric names (matching official DCGM field names)
# Reference: https://docs.nvidia.com/datacenter/dcgm/latest/dcgm-api/dcgm-api-field-ids.html
FIELD_MAPPING = {
    '150': ('DCGM_FI_DEV_GPU_TEMP', 'GPU temperature in Celsius'),
    '155': ('DCGM_FI_DEV_POWER_USAGE', 'Power usage in watts'),
    '203': ('DCGM_FI_DEV_GPU_UTIL', 'GPU utilization percentage'),
    '204': ('DCGM_FI_DEV_MEM_COPY_UTIL', 'Memory utilization percentage'),
    '100': ('DCGM_FI_DEV_SM_CLOCK', 'SM clock in MHz'),
    '101': ('DCGM_FI_DEV_MEM_CLOCK', 'Memory clock in MHz'),
    '250': ('DCGM_FI_DEV_FB_TOTAL', 'Total framebuffer in MB'),
    '251': ('DCGM_FI_DEV_FB_FREE', 'Free framebuffer in MB'),
    '252': ('DCGM_FI_DEV_FB_USED', 'Used framebuffer in MB'),
}


def get_gpu_info():
    """Get GPU information (model names, UUID, PCI) from dcgmi discovery command."""
    gpu_info = {}

    # GPU models that dcgm_fake_manager.py injects (in order)
    gpu_models = [
        "Tesla V100-SXM2-16GB", "Tesla V100-SXM2-32GB", "A100-SXM4-40GB",
        "A100-SXM4-80GB", "H100-SXM5-80GB", "A100-PCIE-40GB"
    ]

    try:
        # First, try to get GPU info from dcgmi discovery
        result = subprocess.run([DCGMI_PATH, 'discovery', '-l'],
                                capture_output=True,
                                text=True,
                                timeout=5,
                                env=os.environ.copy())
        if result.returncode == 0:
            # Parse output to extract GPU ID, model name, and UUID
            # Example output formats:
            # 1 GPU 1: Tesla V100-SXM2-16GB (UUID: GPU-00000001-fake-dcgm-0001-000400000001)
            # OR (if UUID not available):
            # 1 GPU 1: <<<NULL>>> (UUID: <<<NULL>>>)
            lines = result.stdout.strip().split('\n')
            for line in lines:
                # Try to match lines with UUID
                match = re.match(
                    r'^\d+\s+GPU\s+(\d+):\s+([^(]+)\(UUID:\s+([^)]+)\)', line)
                if match:
                    gpu_id = match.group(1)
                    model_name = match.group(2).strip()
                    uuid = match.group(3).strip()

                    # Skip GPU 0
                    if gpu_id == '0':
                        continue

                    gpu_idx = int(gpu_id)

                    # Calculate PCI bus ID based on GPU index (matches dcgm_fake_manager.py)
                    pci_bus_id = f"00000000:{gpu_idx:02x}:00.0"

                    # Handle <<<NULL>>> values from DCGM fake entities
                    # Use the same model names that dcgm_fake_manager.py injects
                    if model_name == '<<<NULL>>>' or not model_name:
                        model_name = gpu_models[(gpu_idx - 1) %
                                                len(gpu_models)]

                    if uuid == '<<<NULL>>>' or not uuid:
                        # Generate UUID matching dcgm_fake_manager.py format
                        num_gpus = int(os.environ.get('NUM_FAKE_GPUS', '4'))
                        uuid = f"GPU-{gpu_idx:08x}-fake-dcgm-{gpu_idx:04x}-{num_gpus:04x}{gpu_idx:08x}"

                    gpu_info[gpu_id] = {
                        'modelName': model_name,
                        'UUID': uuid,
                        'pci_bus_id': pci_bus_id
                    }

        # If no GPUs found via discovery, generate default info for expected GPUs
        if not gpu_info:
            print(
                "Warning: dcgmi discovery returned no GPUs, generating default info",
                flush=True)
            num_gpus = int(os.environ.get('NUM_FAKE_GPUS', '4'))
            gpu_start_index = int(os.environ.get('GPU_START_INDEX', '1'))

            for i in range(num_gpus):
                gpu_idx = gpu_start_index + i
                gpu_id = str(gpu_idx)

                # Skip GPU 0
                if gpu_id == '0':
                    continue

                model_name = gpu_models[i % len(gpu_models)]
                pci_bus_id = f"00000000:{gpu_idx:02x}:00.0"
                uuid = f"GPU-{gpu_idx:08x}-fake-dcgm-{gpu_idx:04x}-{num_gpus:04x}{gpu_idx:08x}"

                gpu_info[gpu_id] = {
                    'modelName': model_name,
                    'UUID': uuid,
                    'pci_bus_id': pci_bus_id
                }

    except Exception as e:
        print(f"Warning: Could not get GPU info: {e}", flush=True)
        # Generate default info as fallback
        num_gpus = int(os.environ.get('NUM_FAKE_GPUS', '4'))
        gpu_start_index = int(os.environ.get('GPU_START_INDEX', '1'))

        for i in range(num_gpus):
            gpu_idx = gpu_start_index + i
            gpu_id = str(gpu_idx)

            if gpu_id == '0':
                continue

            model_name = gpu_models[i % len(gpu_models)]
            pci_bus_id = f"00000000:{gpu_idx:02x}:00.0"
            uuid = f"GPU-{gpu_idx:08x}-fake-dcgm-{gpu_idx:04x}-{num_gpus:04x}{gpu_idx:08x}"

            gpu_info[gpu_id] = {
                'modelName': model_name,
                'UUID': uuid,
                'pci_bus_id': pci_bus_id
            }

    return gpu_info


def parse_dcgmi_output(output):
    metrics = {}
    lines = output.strip().split('\n')
    for line in lines:
        if line.startswith('GPU '):
            parts = line.split()
            if len(parts) >= 2:
                gpu_id = parts[1]
                if gpu_id == '0':
                    continue
                values = parts[2:]
                if gpu_id not in metrics:
                    metrics[gpu_id] = {}
                field_ids = list(FIELD_MAPPING.keys())
                for idx, val in enumerate(values):
                    if idx < len(field_ids):
                        field_id = field_ids[idx]
                        if val != 'N/A':
                            try:
                                metrics[gpu_id][field_id] = float(val)
                            except ValueError:
                                pass
    return metrics


def collect_metrics():
    try:
        # Get GPU info - use cached version
        with gpu_info_lock:
            gpu_info = gpu_info_cache.copy()

        field_ids = ','.join(FIELD_MAPPING.keys())
        result = subprocess.run(
            [DCGMI_PATH, 'dmon', '-e', field_ids, '-c', '1'],
            capture_output=True,
            text=True,
            timeout=5,
            env=os.environ.copy())
        if result.returncode != 0:
            print(f"dcgmi error: {result.stderr}", flush=True)
            return "# Error: dcgmi command failed\n"
        gpu_metrics = parse_dcgmi_output(result.stdout)
        lines = []
        for gpu_id, fields in gpu_metrics.items():
            # Get GPU info for this GPU
            info = gpu_info.get(gpu_id, {})
            model_name = info.get('modelName', 'Unknown')
            uuid = info.get('UUID', 'Unknown')
            pci_bus_id = info.get('pci_bus_id', 'Unknown')

            # Build labels matching real DCGM exporter format
            # Note: Using consistent label names with real DCGM metrics
            labels = f'gpu="{gpu_id}",device="nvidia{gpu_id}",Hostname="{HOSTNAME}",UUID="{uuid}",modelName="{model_name}",pci_bus_id="{pci_bus_id}"'

            for field_id, value in fields.items():
                if field_id in FIELD_MAPPING:
                    metric_name, _ = FIELD_MAPPING[field_id]
                    lines.append(f'{metric_name}{{{labels}}} {value}')
        output = []
        for field_id, (name, help_text) in FIELD_MAPPING.items():
            output.append(f"# HELP {name} {help_text}")
            output.append(f"# TYPE {name} gauge")
        output.extend(sorted(lines))
        return '\n'.join(output) + '\n'
    except subprocess.TimeoutExpired:
        print("dcgmi timeout", flush=True)
        return "# Error: dcgmi timeout\n"
    except Exception as e:
        print(f"Error collecting metrics: {e}", flush=True)
        import traceback
        traceback.print_exc()
        return "# Error: collection failed\n"


def update_metrics_cache():
    global metrics_cache
    while True:
        try:
            with metrics_lock:
                metrics_cache = collect_metrics()
        except Exception as e:
            print(f"Cache update error: {e}", flush=True)
        time.sleep(5)


class MetricsHandler(BaseHTTPRequestHandler):

    def do_GET(self):
        if self.path == '/metrics':
            with metrics_lock:
                response = metrics_cache
            self.send_response(200)
            self.send_header('Content-Type', 'text/plain; charset=utf-8')
            self.end_headers()
            self.wfile.write(response.encode())
        elif self.path == '/health':
            self.send_response(200)
            self.end_headers()
            self.wfile.write(b'OK\n')
        else:
            self.send_response(404)
            self.end_headers()

    def log_message(self, *args):
        pass


if __name__ == '__main__':
    sys.stdout = os.fdopen(sys.stdout.fileno(), 'w', buffering=1)
    sys.stderr = os.fdopen(sys.stderr.fileno(), 'w', buffering=1)
    print("DCGM OpenTelemetry Exporter (CLI-based)", flush=True)
    print(f"Hostname: {HOSTNAME}", flush=True)
    if not os.path.exists(DCGMI_PATH):
        print(f"✗ dcgmi not found at {DCGMI_PATH}", flush=True)
        sys.exit(1)
    print(f"✓ Using dcgmi at {DCGMI_PATH}", flush=True)

    # Get GPU information (model names, UUID, PCI) at startup
    print("Fetching GPU information...", flush=True)
    with gpu_info_lock:
        gpu_info_cache.update(get_gpu_info())
    if gpu_info_cache:
        print(f"✓ Found {len(gpu_info_cache)} GPUs:", flush=True)
        for gpu_id, info in gpu_info_cache.items():
            model = info.get('modelName', 'Unknown')
            uuid = info.get('UUID', 'Unknown')
            pci = info.get('pci_bus_id', 'Unknown')
            print(f"  GPU {gpu_id}: {model}", flush=True)
            print(f"    UUID: {uuid}", flush=True)
            print(f"    PCI:  {pci}", flush=True)
    else:
        print("⚠ No GPU info found (will use 'Unknown' for labels)",
              flush=True)

    print("Testing dcgmi...", flush=True)
    try:
        test_result = collect_metrics()
        print("Sample output:", flush=True)
        print(test_result[:500], flush=True)
    except Exception as e:
        print(f"✗ Test failed: {e}", flush=True)
        import traceback
        traceback.print_exc()
    Thread(target=update_metrics_cache, daemon=True).start()
    port = int(os.environ.get('EXPORTER_PORT', '9400'))
    server = HTTPServer(('0.0.0.0', port), MetricsHandler)
    print(f"✓ Started on port {port}", flush=True)
    print(f"  Metrics: http://localhost:{port}/metrics", flush=True)
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        server.shutdown()
