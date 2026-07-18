# aether-hub

`aether-hub` 是 Tunnel Hub 服务，负责在 proxy 与 worker 之间路由帧。

FastAPI Cloud 只运行 Python 应用，不会启动 Hub sidecar。只有单独部署 Hub 后，才应在 Aether 应用中配置 `TUNNEL_HUB_URL`。

## build.sh 使用说明

- 使用 `cross` 构建 amd64/arm64 二进制。
- `--upload <hub-vX.Y.Z>` 会把构建产物上传到 GitHub Release。

## 运行时参数

- `TUNNEL_HUB_WORKER_IDLE_TIMEOUT`：worker 心跳空闲超时，默认 `60` 秒
- `TUNNEL_HUB_OUTBOUND_QUEUE_CAPACITY`：单连接出站队列容量，默认 `128`；队列打满时会把连接视为拥塞并主动关闭，避免 Hub 内存无限增长
