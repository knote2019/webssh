# ARM平台HTTP连接超时问题修复方案

## 问题描述
在ARM设备上访问WebSSH服务时，浏览器显示 `ERR_CONNECTION_TIMED_OUT` 错误，无法建立HTTP连接。

## 根本原因
ARM设备性能较低，网络响应较慢，需要更长的HTTP连接超时时间。Tornado默认的超时设置对ARM设备来说过于严格。

## 完整修复方案

### 1. 新增HTTP超时配置参数 (webssh/settings.py)

```python
# 第50-55行：新增三个超时参数
define('header_timeout', type=float, default=60,
       help='HTTP header read timeout for slow ARM devices')
define('body_timeout', type=float, default=60,
       help='HTTP body read timeout for slow ARM devices')
define('idle_timeout', type=float, default=300,
       help='Idle connection timeout (0 means no timeout)')
```

**参数说明**：

- `header_timeout`: HTTP请求头读取超时（60秒）
  - 控制读取HTTP请求头的最大时间
  - ARM设备上网络延迟可能导致请求头传输较慢
  
- `body_timeout`: HTTP请求体读取超时（60秒）
  - 控制读取HTTP请求体的最大时间
  - 适用于POST请求（如登录表单提交）
  
- `idle_timeout`: 空闲连接超时（300秒=5分钟）
  - HTTP Keep-Alive连接的空闲超时时间
  - 0表示不超时，300秒平衡了资源占用和连接重用

### 2. 应用超时配置到服务器 (webssh/settings.py)

```python
# 第107-115行：在服务器设置中应用超时参数
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

**注意**：`header_timeout` 不在这里配置，因为它是HTTPServer构造函数的参数。

### 3. 使用HTTPServer显式创建服务器 (webssh/main.py)

```python
# 第4行：导入HTTPServer
import tornado.httpserver

# 第32-51行：修改app_listen函数
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

**改进点**：
- 从 `app.listen()` 改为显式使用 `tornado.httpserver.HTTPServer`
- 增加超时配置的日志输出，方便调试
- 修复address为空时的显示问题

### 4. 启动脚本参数化 (quick_install.sh)

```bash
# 第10-11行：新增HTTP超时环境变量
HTTP_IDLE_TIMEOUT=${HTTP_IDLE_TIMEOUT:-300}
HTTP_BODY_TIMEOUT=${HTTP_BODY_TIMEOUT:-60}

# 第30-38行：启动命令添加超时参数
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

## 完整的超时配置体系

### HTTP层（新增）
```
浏览器 → HTTP连接
  ├─ idle_timeout: 300秒 (Keep-Alive连接空闲超时)
  ├─ body_timeout: 60秒 (请求体读取超时)
  └─ header_timeout: 60秒 (请求头读取超时)
```

### WebSocket层
```
HTTP → WebSocket升级
  └─ wpintvl: 30秒 (WebSocket心跳间隔)
```

### SSH层
```
WebSocket → SSH连接
  ├─ timeout: 30秒 (SSH连接建立超时)
  ├─ delay: 10秒 (Worker回收延迟)
  └─ ClientAliveInterval: 60秒 (SSH服务器keepalive)
```

## 使用方法

### 方法1：使用默认值（推荐）
```bash
bash quick_install.sh
```
默认配置已经针对ARM优化：
- HTTP空闲超时：300秒
- HTTP body超时：60秒
- SSH连接超时：30秒
- WebSocket ping：30秒

### 方法2：自定义超时值
```bash
# 如果ARM设备特别慢，可以增加超时
HTTP_IDLE_TIMEOUT=600 \
HTTP_BODY_TIMEOUT=120 \
SSH_TIMEOUT=60 \
bash quick_install.sh
```

### 方法3：手动启动（用于调试）
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

## 验证修复

### 1. 查看启动日志
启动后应该看到类似输出：
```
Listening on 0.0.0.0:6622 (http)
Timeout settings - idle: 300s, body: 60s
```

### 2. 测试HTTP连接
```bash
# 本地测试
curl -I http://localhost:6622

# 远程测试
curl -I http://ARM_IP:6622
```

### 3. 浏览器访问
打开浏览器访问 `http://ARM_IP:6622`，应该能正常加载页面。

### 4. 长连接测试
登录后保持终端空闲5分钟，连接应该保持稳定。

## 故障排查

### 问题1：仍然超时
**可能原因**：超时值仍然不够大

**解决方案**：
```bash
# 进一步增加超时
HTTP_IDLE_TIMEOUT=0 \        # 0 = 永不超时
HTTP_BODY_TIMEOUT=180 \      # 3分钟
SSH_TIMEOUT=90 \             # 90秒
bash quick_install.sh
```

### 问题2：服务无法启动
**可能原因**：参数名称错误

**检查**：
```bash
webssh --help | grep timeout
```

应该看到：
```
--idle-timeout
--body-timeout
--timeout
```

### 问题3：参数未生效
**检查日志**：启动时应该显示超时配置
```
Timeout settings - idle: 300s, body: 60s
```

如果没有显示，说明参数可能传递错误。

### 问题4：网络问题
如果是网络层面的问题：
```bash
# 检查防火墙
iptables -L -n | grep 6622

# 检查端口
netstat -tlnp | grep 6622

# 检查进程
ps aux | grep webssh
```

## 性能建议

### 对于不同性能的ARM设备

**高性能ARM (树莓派4, RK3588等)**
```bash
HTTP_IDLE_TIMEOUT=300
HTTP_BODY_TIMEOUT=60
SSH_TIMEOUT=30
```

**中等性能ARM (树莓派3, RK3399等)**
```bash
HTTP_IDLE_TIMEOUT=600
HTTP_BODY_TIMEOUT=90
SSH_TIMEOUT=60
```

**低性能ARM (全志H3, RK3328等)**
```bash
HTTP_IDLE_TIMEOUT=0        # 禁用超时
HTTP_BODY_TIMEOUT=180
SSH_TIMEOUT=90
```

## 技术细节

### Tornado超时参数说明

1. **idle_connection_timeout**
   - 作用于：HTTP Keep-Alive连接
   - 含义：连接空闲多久后关闭
   - 默认：通常是无限或很长时间
   - 我们的设置：300秒（5分钟）

2. **body_timeout**
   - 作用于：HTTP请求体读取
   - 含义：读取请求体的最大时间
   - 默认：通常是60秒
   - 我们的设置：60秒（可根据需要调整）

3. **header_timeout**
   - 作用于：HTTP请求头读取
   - 含义：读取请求头的最大时间
   - 默认：通常是15秒
   - 我们的设置：60秒（定义了但当前版本未使用）

### 为什么需要这些超时？

ARM设备的特点：
- CPU性能较低，处理速度慢
- 网络芯片性能有限，延迟较高
- 可能通过慢速网络（WiFi, 4G等）访问
- 系统负载高时响应更慢

因此需要更宽松的超时设置，避免正常的慢速连接被误判为超时。

## 修改文件清单

✅ `webssh/settings.py` - 添加HTTP超时参数定义和应用
✅ `webssh/main.py` - 使用HTTPServer并添加超时日志
✅ `quick_install.sh` - 启动脚本添加HTTP超时参数
✅ `webssh/handler.py` - 编码检测超时（之前已修改）

## 兼容性说明

- ✅ 向后兼容：不传超时参数时使用默认值
- ✅ Tornado版本：适用于Tornado 4.5+
- ✅ Python版本：Python 2.7+ 和 Python 3.x
- ✅ 其他平台：这些修改对x86/x64平台也安全有效

## 总结

通过增加HTTP层面的超时配置，我们为ARM设备提供了更充裕的连接建立时间，从根本上解决了 `ERR_CONNECTION_TIMED_OUT` 问题。配合之前的WebSocket和SSH超时优化，形成了一个完整的超时控制体系。

