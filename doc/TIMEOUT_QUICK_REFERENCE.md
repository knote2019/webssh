# ARM WebSSH Timeout Configuration Quick Reference

## Quick Fix

```bash
# Stop existing service
pkill webssh

# Restart (apply new configuration)
bash quick_install.sh
```

## All Timeout Parameters Overview

| Parameter | Layer | Default | Purpose | Recommended |
|-----------|-------|---------|---------|-------------|
| `idle_timeout` | HTTP | 300s | HTTP Keep-Alive idle timeout | 300-600s |
| `body_timeout` | HTTP | 60s | HTTP request body read timeout | 60-120s |
| `header_timeout` | HTTP | 60s | HTTP request header read timeout | 60s |
| `wpintvl` | WebSocket | 30s | WebSocket heartbeat interval | 30s |
| `timeout` | SSH | 30s | SSH connection establishment timeout | 30-60s |
| `delay` | Worker | 10s | Worker recycle delay | 10-20s |
| `ClientAliveInterval` | SSH Server | 60s | SSH keepalive interval | 60s |

## Command Line Parameter Reference

| Environment Variable | Command Line Parameter | Configuration |
|---------------------|------------------------|---------------|
| `HTTP_IDLE_TIMEOUT` | `--idle-timeout` | `idle_timeout` |
| `HTTP_BODY_TIMEOUT` | `--body-timeout` | `body_timeout` |
| `SSH_TIMEOUT` | `--timeout` | `timeout` |
| `WS_PING_INTERVAL` | `--wpintvl` | `wpintvl` |
| `WORKER_DELAY` | `--delay` | `delay` |

## Common Scenario Configurations

### Scenario 1: Default Configuration (Suitable for Most ARM Devices)
```bash
bash quick_install.sh
```

### Scenario 2: Very Slow ARM Device
```bash
HTTP_IDLE_TIMEOUT=0 \
HTTP_BODY_TIMEOUT=180 \
SSH_TIMEOUT=90 \
WORKER_DELAY=30 \
bash quick_install.sh
```

### Scenario 3: Unstable Network
```bash
HTTP_IDLE_TIMEOUT=600 \
WS_PING_INTERVAL=20 \
bash quick_install.sh
```

### Scenario 4: Debug Mode
```bash
webssh --port=6622 \
       --timeout=120 \
       --idle-timeout=0 \
       --body-timeout=300 \
       --debug=True
```

## Verification Commands

```bash
# 1. Check service running
ps aux | grep webssh

# 2. Check port listening
netstat -tlnp | grep 6622

# 3. Test HTTP connection
curl -I http://localhost:6622

# 4. View timeout configuration in logs
# Should see: Timeout settings - idle: XXXs, body: XXXs
```

## Modified Files

- ✅ `webssh/settings.py` - 3 new parameters
- ✅ `webssh/main.py` - HTTPServer + logging
- ✅ `quick_install.sh` - 2 new environment variables

## Problem Diagnosis

| Problem | Possible Cause | Solution |
|---------|---------------|----------|
| ERR_CONNECTION_TIMED_OUT | HTTP connection timeout | Increase `idle_timeout` and `body_timeout` |
| WebSocket disconnects | Missing heartbeat | Check `wpintvl=30` |
| SSH connection fails | SSH timeout too short | Increase `timeout` to 60 or 90 |
| Disconnects immediately after connection | Worker recycled | Increase `delay` to 20 or 30 |

## Key Modification Points

### settings.py (Lines 50-55)
```python
define('header_timeout', type=float, default=60, ...)
define('body_timeout', type=float, default=60, ...)
define('idle_timeout', type=float, default=300, ...)
```

### settings.py (Lines 108-109)
```python
idle_connection_timeout=options.idle_timeout,
body_timeout=options.body_timeout
```

### main.py (Line 4)
```python
import tornado.httpserver
```

### main.py (Line 34)
```python
server = tornado.httpserver.HTTPServer(app, **server_settings)
```

### quick_install.sh (Lines 10-11, 37-38)
```bash
HTTP_IDLE_TIMEOUT=${HTTP_IDLE_TIMEOUT:-300}
HTTP_BODY_TIMEOUT=${HTTP_BODY_TIMEOUT:-60}
...
--idle-timeout="$HTTP_IDLE_TIMEOUT" \
--body-timeout="$HTTP_BODY_TIMEOUT" &
```
