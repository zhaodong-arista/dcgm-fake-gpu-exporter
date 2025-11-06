# 🚨 Alerting Guide

This project demonstrates **Prometheus alerting** for GPU monitoring with an option to add Grafana-native alerts if needed.

## 📊 Current Alerting Strategy

### **Prometheus Alerts (Recommended)**

We use Prometheus for alerting because:
- ✅ **Production-ready** - Battle-tested, widely adopted
- ✅ **Powerful query language** - PromQL for complex conditions  
- ✅ **Alertmanager integration** - Sophisticated routing (PagerDuty, Slack, email)
- ✅ **Version controlled** - YAML files in Git
- ✅ **No dependencies** - Works independently

| Feature | Prometheus Alerts | Grafana Alerts |
|---------|------------------|----------------|
| **Best For** | Production deployments | Visual dashboards |
| **Configuration** | YAML (version controlled) | Web UI or YAML |
| **Alert Routing** | Alertmanager (powerful) | Contact points (good) |
| **Query Language** | PromQL | PromQL |
| **Demo Impact** | Professional | Visual |

### **Our Setup:**
- ✅ 8 Prometheus alert rules (production-grade)
- ✅ Can add Grafana alerts later if needed (optional)
- ✅ Focus on simplicity and reliability

---

## 🔥 Prometheus Alerts

### Location
- **File**: `grafana/provisioning/alerts/gpu_alerts.yml`
- **View**: http://localhost:9090/alerts

### Alert Rules (8 Total)

```yaml
# Example: High Temperature Alert
- alert: GPUHighTemperature
  expr: DCGM_FI_DEV_GPU_TEMP > 75
  for: 1m
  labels:
    severity: warning
  annotations:
    summary: "GPU {{ $labels.gpu }} temperature critical"
    description: "Temperature: {{ $value }}°C"
```

### Which Alerts Will Fire?

With the default demo profiles:

| Profile | Expected Alerts |
|---------|----------------|
| **wave** 🌊 | GPUUtilizationSpike, GPUHighTemperature |
| **spike** 📈 | GPUUtilizationSpike (frequently), GPUHighUtilization |
| **stable** 😴 | None (baseline) |
| **degrading** 📉 | GPUDegradingPerformance |

### Viewing Prometheus Alerts

1. Open http://localhost:9090/alerts
2. You'll see:
   - **Green** = Inactive (normal)
   - **Yellow** = Pending (evaluating)
   - **Red** = Firing (alert active!)
3. Click on an alert to see details

---

## 📊 Grafana Alerts

### Location
- **File**: `grafana/provisioning/alerting/alerting.yml`
- **View**: http://localhost:3000 → Alerting → Alert rules

### Alert Rules (3 Total)

1. **GPU High Temperature** - Temp > 75°C for 30sec
2. **GPU Utilization Spike** - Rate change > 40%
3. **GPU High Memory Usage** - Memory > 80% for 1min

### How to View

1. **In Grafana Dashboard**:
   - Open http://localhost:3000
   - Look for 🔔 bell icons on panels
   - Alert states show directly on graphs!

2. **In Alerting Page**:
   - Navigate to: Alerting → Alert rules
   - See all rules and their states
   - Configure contact points (email, Slack, etc.)

### Setting Up Notifications

To add Slack/Email notifications:

1. Go to Alerting → Contact points
2. Click "New contact point"
3. Choose type (Slack, Email, PagerDuty, etc.)
4. Configure credentials
5. Test notification

---

## 🎬 Demo Recommendations

### For Maximum Impact

**Option 1: Grafana-Only (Recommended for Presentations)**
```bash
# Start the demo
cd deployments
docker-compose -f docker-compose-demo.yml up -d

# Open Grafana
open http://localhost:3000

# Show:
✅ Dashboard with live updating graphs
✅ Alert indicators directly on panels
✅ Alerting page showing fired alerts
✅ Everything in one beautiful UI!
```

**Option 2: Full Stack (Recommended for Technical Audiences)**
```bash
# Show both systems working together
open http://localhost:3000      # Grafana dashboards + alerts
open http://localhost:9090/alerts  # Prometheus alert engine
open http://localhost:9090/graph   # Prometheus queries

# Explain:
✅ Prometheus = Alert engine (powerful queries)
✅ Grafana = Visualization + user-friendly alerts
✅ Best of both worlds!
```

### Fast Alert Triggers (for Demos)

Want alerts to fire quickly?

```bash
# Use spike profile with 2-second updates
docker-compose -f docker-compose-demo.yml down
```

Edit `docker-compose-demo.yml`:
```yaml
environment:
  - NUM_FAKE_GPUS=4
  - GPU_PROFILES=spike,spike,wave,faulty  # More aggressive profiles
  - METRIC_UPDATE_INTERVAL=2  # Update every 2 seconds!
```

```bash
docker-compose -f docker-compose-demo.yml up -d
```

Now alerts will fire within 30-60 seconds! 🔥

---

## 🔧 Customizing Alerts

### Prometheus Alert Thresholds

Edit `grafana/provisioning/alerts/gpu_alerts.yml`:

```yaml
# Make alerts more sensitive
- alert: GPUHighTemperature
  expr: DCGM_FI_DEV_GPU_TEMP > 60  # Lower from 75°C
  for: 30s                         # Shorter duration
```

### Grafana Alert Thresholds

Edit `grafana/provisioning/alerting/alerting.yml`:

```yaml
# Adjust temperature threshold
evaluator:
  params:
    - 60  # Lower from 75
  type: gt
```

Then restart:
```bash
docker-compose -f docker-compose-demo.yml restart prometheus-demo grafana-demo
```

---

## 📸 Screenshots for README

Recommended screenshots to showcase:

1. **Grafana Dashboard** with alert indicators
2. **Prometheus Alerts Page** showing fired alerts
3. **Grafana Alerting Page** with rule details
4. **Side-by-side** comparison of both systems

---

## 🐛 Troubleshooting

### "No alerts firing"

**Problem**: All alerts show as "Inactive"

**Solutions**:
1. Wait 1-2 minutes for metrics to accumulate
2. Use `spike` or `wave` profiles (they trigger alerts faster)
3. Lower METRIC_UPDATE_INTERVAL to 2-5 seconds
4. Check Prometheus targets: http://localhost:9090/targets

### "Duplicate GPUs in Grafana"

**Problem**: Shows GPU 1, GPU 1, GPU 2, GPU 2 (old data)

**Solution**:
```bash
# Clear Prometheus/Grafana data
docker-compose -f docker-compose-demo.yml down -v
docker-compose -f docker-compose-demo.yml up -d
```

### "Alerts not loading in Grafana"

**Problem**: Alerting page shows no rules

**Solutions**:
1. Check unified alerting is enabled:
   - Settings → Alerting → Unified Alerting: ON
2. Verify provisioning files are mounted:
   ```bash
   docker exec grafana-demo ls /etc/grafana/provisioning/alerting/
   ```
3. Check Grafana logs:
   ```bash
   docker logs grafana-demo
   ```

---

## 🎓 Learning Resources

- [Prometheus Alerting Rules](https://prometheus.io/docs/prometheus/latest/configuration/alerting_rules/)
- [Grafana Unified Alerting](https://grafana.com/docs/grafana/latest/alerting/)
- [DCGM Metrics Reference](https://docs.nvidia.com/datacenter/dcgm/latest/dcgm-api/dcgm-api-field-ids.html)

---

## 💡 Production Tips

For real-world deployments:

1. **Use Alertmanager** (Prometheus) for complex routing
2. **Set up contact points** (Grafana) for notifications
3. **Tune alert thresholds** based on your GPU workloads
4. **Add silences** for maintenance windows
5. **Create runbooks** linked in alert annotations
6. **Monitor alert fatigue** - too many alerts = ignored alerts!

---

**Need Help?** See [CONTRIBUTING.md](../CONTRIBUTING.md) or open an issue!
