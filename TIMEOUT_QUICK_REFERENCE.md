# ARM WebSSH 超时配置速查表

## 快速修复

```bash
# 停止现有服务
pkill webssh

# 重新启动（应用新配置）
bash quick_install.sh
```

## 所有超时参数一览

| 参数 | 位置 | 默认值 | 作用 | 推荐值 |
|------|------|--------|------|--------|
| `idle_timeout` | HTTP层 | 300秒 | HTTP Keep-Alive空闲超时 | 300-600秒 |
| `body_timeout` | HTTP层 | 60秒 | HTTP请求体读取超时 | 60-120秒 |
| `header_timeout` | HTTP层 | 60秒 | HTTP请求头读取超时 | 60秒 |
| `wpintvl` | WebSocket层 | 30秒 | WebSocket心跳间隔 | 30秒 |
| `timeout` | SSH层 | 30秒 | SSH连接建立超时 | 30-60秒 |
| `delay` | Worker层 | 10秒 | Worker回收延迟 | 10-20秒 |
| `ClientAliveInterval` | SSH服务器 | 60秒 | SSH keepalive间隔 | 60秒 |

## 命令行参数对照表

| 环境变量 | 命令行参数 | 对应配置 |
|---------|-----------|---------|
| `HTTP_IDLE_TIMEOUT` | `--idle-timeout` | `idle_timeout` |
| `HTTP_BODY_TIMEOUT` | `--body-timeout` | `body_timeout` |
| `SSH_TIMEOUT` | `--timeout` | `timeout` |
| `WS_PING_INTERVAL` | `--wpintvl` | `wpintvl` |
| `WORKER_DELAY` | `--delay` | `delay` |

## 常见场景配置

### 场景1：默认配置（适合大多数ARM设备）
```bash
bash quick_install.sh
```

### 场景2：极慢的ARM设备
```bash
HTTP_IDLE_TIMEOUT=0 \
HTTP_BODY_TIMEOUT=180 \
SSH_TIMEOUT=90 \
WORKER_DELAY=30 \
bash quick_install.sh
```

### 场景3：网络不稳定
```bash
HTTP_IDLE_TIMEOUT=600 \
WS_PING_INTERVAL=20 \
bash quick_install.sh
```

### 场景4：调试模式
```bash
webssh --port=6622 \
       --timeout=120 \
       --idle-timeout=0 \
       --body-timeout=300 \
       --debug=True
```

## 验证命令

```bash
# 1. 检查服务运行
ps aux | grep webssh

# 2. 检查端口监听
netstat -tlnp | grep 6622

# 3. 测试HTTP连接
curl -I http://localhost:6622

# 4. 查看日志中的超时配置
# 应该看到：Timeout settings - idle: XXXs, body: XXXs
```

## 修改的文件

- ✅ `webssh/settings.py` - 3个新参数
- ✅ `webssh/main.py` - HTTPServer + 日志
- ✅ `quick_install.sh` - 2个新环境变量

## 问题诊断

| 问题 | 可能原因 | 解决方案 |
|------|---------|---------|
| ERR_CONNECTION_TIMED_OUT | HTTP连接超时 | 增加 `idle_timeout` 和 `body_timeout` |
| WebSocket断开 | 缺少心跳 | 检查 `wpintvl=30` |
| SSH连接失败 | SSH超时太短 | 增加 `timeout` 到60或90 |
| 连接建立后立即断开 | Worker被回收 | 增加 `delay` 到20或30 |

## 关键修改点

### settings.py (第50-55行)
```python
define('header_timeout', type=float, default=60, ...)
define('body_timeout', type=float, default=60, ...)
define('idle_timeout', type=float, default=300, ...)
```

### settings.py (第108-109行)
```python
idle_connection_timeout=options.idle_timeout,
body_timeout=options.body_timeout
```

### main.py (第4行)
```python
import tornado.httpserver
```

### main.py (第34行)
```python
server = tornado.httpserver.HTTPServer(app, **server_settings)
```

### quick_install.sh (第10-11, 37-38行)
```bash
HTTP_IDLE_TIMEOUT=${HTTP_IDLE_TIMEOUT:-300}
HTTP_BODY_TIMEOUT=${HTTP_BODY_TIMEOUT:-60}
...
--idle-timeout="$HTTP_IDLE_TIMEOUT" \
--body-timeout="$HTTP_BODY_TIMEOUT" &
```

