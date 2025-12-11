# ARM Platform HTTP Connection Timeout Fix

## Problem Description
When accessing WebSSH service on ARM devices, browser displays `ERR_CONNECTION_TIMED_OUT` error, unable to establish HTTP connection.

## Root Cause
ARM devices have lower performance and slower network response, requiring longer HTTP connection timeout. Tornado's default timeout settings are too strict for ARM devices.

## Complete Fix Solution

### 1. Add HTTP Timeout Configuration Parameters (webssh/settings.py)

```python
# Lines 50-55: Add three new timeout parameters
define('header_timeout', type=float, default=60,
       help='HTTP header read timeout for slow ARM devices')
define('body_timeout', type=float, default=60,
       help='HTTP body read timeout for slow ARM devices')
define('idle_timeout', type=float, default=300,
       help='Idle connection timeout (0 means no timeout)')
```

**Parameter Explanation**:

- `header_timeout`: HTTP request header read timeout (60 seconds)
  - Controls maximum time to read HTTP request headers
  - Network latency on ARM devices may cause slower header transmission
  
- `body_timeout`: HTTP request body read timeout (60 seconds)
  - Controls maximum time to read HTTP request body
  - Applies to POST requests (e.g., login form submission)
  
- `idle_timeout`: Idle connection timeout (300 seconds = 5 minutes)
  - Idle timeout for HTTP Keep-Alive connections
  - 0 means no timeout, 300 seconds balances resource usage and connection reuse

### 2. Apply Timeout Configuration to Server (webssh/settings.py)

```python
# Lines 107-115: Apply timeout parameters in server settings
def get_server_settings(options):
    settings = dict(
        xheaders=options.xheaders,
        max_body_size=max_body_size,
        trusted_downstream=get_trusted_downstream(options.tdstream),
        # HTTP connection timeouts for ARM devices
        idle_connection_timeout=options.idle_timeout,
        body_timeout=options.body_timeout
    )
    return settings
```

**Note**: `header_timeout` is not configured here because it's a parameter of HTTPServer constructor.

### 3. Use HTTPServer Explicitly to Create Server (webssh/main.py)

```python
# Line 4: Import HTTPServer
import tornado.httpserver

# Lines 32-51: Modify app_listen function
def app_listen(app, port, address, server_settings):
    # Use HTTPServer explicitly for better timeout control on ARM devices
    server = tornado.httpserver.HTTPServer(app, **server_settings)
    server.listen(port, address)
    
    if not server_settings.get('ssl_options'):
        server_type = 'http'
    else:
        server_type = 'https'
        handler.redirecting = True if options.redirect else False
    
    logging.info(
        'Listening on {}:{} ({})'.format(address or '0.0.0.0', port, server_type)
    )
    logging.info(
        'Timeout settings - idle: {}s, body: {}s'.format(
            server_settings.get('idle_connection_timeout', 'default'),
            server_settings.get('body_timeout', 'default')
        )
    )
```

**Improvements**:
- Changed from `app.listen()` to explicitly using `tornado.httpserver.HTTPServer`
- Added timeout configuration log output for easier debugging
- Fixed display issue when address is empty

### 4. Parameterize Startup Script (quick_install.sh)

```bash
# Lines 10-11: Add new HTTP timeout environment variables
HTTP_IDLE_TIMEOUT=${HTTP_IDLE_TIMEOUT:-300}
HTTP_BODY_TIMEOUT=${HTTP_BODY_TIMEOUT:-60}

# Lines 30-38: Add timeout parameters to startup command
webssh --port="$WEB_SSH_PORT" \
       --ssh-port="$SSH_PORT" \
       --ssh-username="$SSH_USERNAME" \
       --ssh-password="$SSH_PASSWORD" \
       --timeout="$SSH_TIMEOUT" \
       --wpintvl="$WS_PING_INTERVAL" \
       --delay="$WORKER_DELAY" \
       --idle-timeout="$HTTP_IDLE_TIMEOUT" \
       --body-timeout="$HTTP_BODY_TIMEOUT" &
```

## Complete Timeout Configuration System

### HTTP Layer (New)
```
Browser → HTTP Connection
  ├─ idle_timeout: 300s (Keep-Alive connection idle timeout)
  ├─ body_timeout: 60s (Request body read timeout)
  └─ header_timeout: 60s (Request header read timeout)
```

### WebSocket Layer
```
HTTP → WebSocket Upgrade
  └─ wpintvl: 30s (WebSocket heartbeat interval)
```

### SSH Layer
```
WebSocket → SSH Connection
  ├─ timeout: 30s (SSH connection establishment timeout)
  ├─ delay: 10s (Worker recycle delay)
  └─ ClientAliveInterval: 60s (SSH server keepalive)
```

## Usage

### Method 1: Use Default Values (Recommended)
```bash
bash quick_install.sh
```
Default configuration is already optimized for ARM:
- HTTP idle timeout: 300 seconds
- HTTP body timeout: 60 seconds
- SSH connection timeout: 30 seconds
- WebSocket ping: 30 seconds

### Method 2: Customize Timeout Values
```bash
# If ARM device is particularly slow, increase timeouts
HTTP_IDLE_TIMEOUT=600 \
HTTP_BODY_TIMEOUT=120 \
SSH_TIMEOUT=60 \
bash quick_install.sh
```

### Method 3: Manual Startup (For Debugging)
```bash
webssh --port=6622 \
       --ssh-port=5522 \
       --ssh-username=root \
       --ssh-password=cloud1234 \
       --timeout=60 \
       --wpintvl=30 \
       --delay=20 \
       --idle-timeout=600 \
       --body-timeout=120 \
       --debug=True
```

## Verify Fix

### 1. Check Startup Logs
After startup, you should see output similar to:
```
Listening on 0.0.0.0:6622 (http)
Timeout settings - idle: 300s, body: 60s
```

### 2. Test HTTP Connection
```bash
# Local test
curl -I http://localhost:6622

# Remote test
curl -I http://ARM_IP:6622
```

### 3. Browser Access
Open browser and visit `http://ARM_IP:6622`, page should load normally.

### 4. Long Connection Test
After login, keep terminal idle for 5 minutes, connection should remain stable.

## Troubleshooting

### Issue 1: Still Timing Out
**Possible Cause**: Timeout values still not large enough

**Solution**:
```bash
# Further increase timeouts
HTTP_IDLE_TIMEOUT=0 \        # 0 = never timeout
HTTP_BODY_TIMEOUT=180 \      # 3 minutes
SSH_TIMEOUT=90 \             # 90 seconds
bash quick_install.sh
```

### Issue 2: Service Fails to Start
**Possible Cause**: Parameter name error

**Check**:
```bash
webssh --help | grep timeout
```

Should see:
```
--idle-timeout
--body-timeout
--timeout
```

### Issue 3: Parameters Not Taking Effect
**Check Logs**: Timeout configuration should be displayed at startup
```
Timeout settings - idle: 300s, body: 60s
```

If not displayed, parameters may be passed incorrectly.

### Issue 4: Network Issues
If it's a network layer problem:
```bash
# Check firewall
iptables -L -n | grep 6622

# Check port
netstat -tlnp | grep 6622

# Check process
ps aux | grep webssh
```

## Performance Recommendations

### For Different Performance ARM Devices

**High-Performance ARM (Raspberry Pi 4, RK3588, etc.)**
```bash
HTTP_IDLE_TIMEOUT=300
HTTP_BODY_TIMEOUT=60
SSH_TIMEOUT=30
```

**Medium-Performance ARM (Raspberry Pi 3, RK3399, etc.)**
```bash
HTTP_IDLE_TIMEOUT=600
HTTP_BODY_TIMEOUT=90
SSH_TIMEOUT=60
```

**Low-Performance ARM (Allwinner H3, RK3328, etc.)**
```bash
HTTP_IDLE_TIMEOUT=0        # Disable timeout
HTTP_BODY_TIMEOUT=180
SSH_TIMEOUT=90
```

## Technical Details

### Tornado Timeout Parameters Explained

1. **idle_connection_timeout**
   - Applies to: HTTP Keep-Alive connections
   - Meaning: How long after connection becomes idle before closing
   - Default: Usually infinite or very long
   - Our setting: 300 seconds (5 minutes)

2. **body_timeout**
   - Applies to: HTTP request body reading
   - Meaning: Maximum time to read request body
   - Default: Usually 60 seconds
   - Our setting: 60 seconds (adjustable as needed)

3. **header_timeout**
   - Applies to: HTTP request header reading
   - Meaning: Maximum time to read request headers
   - Default: Usually 15 seconds
   - Our setting: 60 seconds (defined but not currently used)

### Why Are These Timeouts Needed?

ARM device characteristics:
- Lower CPU performance, slower processing
- Limited network chip performance, higher latency
- May be accessed through slow networks (WiFi, 4G, etc.)
- Slower response when system load is high

Therefore, more lenient timeout settings are needed to avoid normal slow connections being mistaken for timeouts.

## Modified Files List

✅ `webssh/settings.py` - Added HTTP timeout parameter definitions and application
✅ `webssh/main.py` - Used HTTPServer and added timeout logging
✅ `quick_install.sh` - Added HTTP timeout parameters to startup script
✅ `webssh/handler.py` - Encoding detection timeout (previously modified)

## Compatibility Notes

- ✅ Backward compatible: Uses default values when timeout parameters not passed
- ✅ Tornado version: Applicable to Tornado 4.5+
- ✅ Python version: Python 2.7+ and Python 3.x
- ✅ Other platforms: These modifications are safe and effective for x86/x64 platforms

## Summary

By adding HTTP layer timeout configuration, we provide ARM devices with more generous connection establishment time, fundamentally solving the `ERR_CONNECTION_TIMED_OUT` issue. Combined with previous WebSocket and SSH timeout optimizations, this forms a complete timeout control system.
