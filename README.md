<p align="center">
  <img src="frontend/public/aether_adaptive.svg" width="120" height="120" alt="Aether Logo">
</p>

<h1 align="center">Aether</h1>

<p align="center">
  <strong>一站式 AI 基础设施平台</strong><br>
  支持 Claude / OpenAI / Gemini 及其 CLI 客户端的统一接入、格式转换、正/反向代理, 致力于成为用户驱动AI服务的底座
</p>
<p align="center">
  <a href="#简介">简介</a> •
  <a href="#部署">部署</a> •
  <a href="#环境变量">环境变量</a> •
  <a href="#qa">Q&A</a>
</p>


---

## 简介

Aether 是一个自托管的 AI API 网关，为团队和个人提供多租户管理、智能负载均衡、成本配额控制和健康监控能力。通过统一的 API 入口，可以无缝对接 Claude、OpenAI、Gemini 等主流 AI 服务及其 CLI 工具。

<p align="center">
  <picture>
    <source media="(prefers-color-scheme: dark)" srcset="docs/architecture/architecture-dark.svg">
    <source media="(prefers-color-scheme: light)" srcset="docs/architecture/architecture-light.svg">
    <img src="docs/architecture/architecture-light.svg" width="680" alt="Aether Architecture">
  </picture>
</p>

## 部署

### FastAPI Cloud

项目已按 [FastAPI Cloud 官方部署方式](https://fastapi.tiangolo.com/zh/deployment/fastapicloud/) 配置，Python 入口为 `src.main:app`。同一次部署会提供 API 和 Vue 前端。

数据库层已在 PostgreSQL 18.4 与 Redis 8.6.4 上完成迁移、启动、读写、队列及分布式锁验证，可兼容 PostgreSQL 18.x 和 Redis 8.6.x。应用实际使用 SQLAlchemy + `psycopg2` 访问 PostgreSQL，并通过 `redis.asyncio` 访问 Redis。

先在 FastAPI Cloud 控制台创建应用，准备托管 PostgreSQL 与 Redis。可直接使用控制台中的 Neon 和 Redis Cloud 集成，然后在应用的 **Environment Variables** 中配置下文列出的变量。

```bash
git clone https://github.com/fawney19/Aether.git
cd Aether

# 安装锁定的 Python 依赖与前端依赖
uv sync --frozen
npm --prefix frontend ci

# 登录并关联控制台中已经配置好的应用
uv run fastapi login
uv run fastapi cloud link

# 首次部署前初始化数据库；后续仅在包含迁移时执行
DATABASE_URL='postgresql://...' uv run alembic upgrade head

# FastAPI Cloud 不代建前端，每次部署前先生成 frontend/dist
npm --prefix frontend run build
uv run fastapi deploy
```

`fastapi deploy` 会自动读取 `pyproject.toml`、`uv.lock` 与 `.python-version`，上传时 `.fastapicloudignore` 会包含刚生成的 `frontend/dist` 并排除测试、文档和 Rust 子项目。

也可以在 GitHub Actions 中手动运行 **Deploy to FastAPI Cloud**。关联应用后执行 `uv run fastapi cloud setup-ci --secrets-only`，CLI 会配置前两个 Repository Secrets；数据库 Secret 需要手动添加：

| Secret | 用途 |
|------|------|
| `FASTAPI_CLOUD_TOKEN` | FastAPI Cloud 部署令牌 |
| `FASTAPI_CLOUD_APP_ID` | 目标应用 ID |
| `DATABASE_URL` | CI 执行 Alembic 迁移时使用 |

工作流默认在部署前迁移数据库。若本次迁移包含删除或重命名，应按照 FastAPI Cloud 的零停机原则分阶段操作，并在触发工作流时关闭自动迁移。

### 本地开发

本地需要可访问的 PostgreSQL 和 Redis。将 `.env.example` 复制为 `.env` 后填写连接地址与密钥：

```bash
cp .env.example .env
uv sync --frozen
uv run alembic upgrade head

# 后端热重载
./dev.sh

# 另一个终端运行前端
npm --prefix frontend ci
npm --prefix frontend run dev
```

## Aether Proxy (可选)

Aether Proxy 是配套的正向代理节点，部署在海外 VPS 上，为墙内的 Aether 实例中转 API 流量。或者部署在其他服务器为指定的提供商、账号、Key使用不同的节点访问。支持 TUI 向导一键配置、systemd 服务管理、TLS 加密、DNS 缓存及连接池调优。

- 下载预编译二进制直接运行
- 通过 `aether-proxy setup` 完成交互式配置，自动注册为系统服务
- 详细文档见 [aether-proxy/README.md](aether-proxy/README.md)

FastAPI Cloud 不会启动本地 Hub sidecar，因此 Tunnel 模式默认关闭；使用该能力时需单独部署 Hub 并配置 `TUNNEL_HUB_URL`。

## 环境变量

### 必需配置

| 变量 | 说明 |
|------|------|
| `ENVIRONMENT` | FastAPI Cloud 设置为 `production` |
| `DATABASE_URL` | 托管 PostgreSQL 连接地址 |
| `REDIS_URL` | 托管 Redis 连接地址 |
| `JWT_SECRET_KEY` | JWT 签名密钥（使用 `generate_keys.py` 生成） |
| `ENCRYPTION_KEY` | API Key 加密密钥（更换后需重新配置 Provider Key） |
| `ADMIN_EMAIL` | 初始管理员邮箱 |
| `ADMIN_USERNAME` | 初始管理员用户名 |
| `ADMIN_PASSWORD` | 初始管理员密码 |

### 可选配置

| 变量 | 默认值 | 说明 |
|------|--------|------|
| `PORT` | 8084 | 本地端口；FastAPI Cloud 自动提供 |
| `API_KEY_PREFIX` | sk | API Key 前缀 |
| `LOG_LEVEL` | INFO | 日志级别 (DEBUG/INFO/WARNING/ERROR) |
| `LOG_DISABLE_FILE` | 生产环境为 true | 云端仅输出 stdout 日志 |
| `DOCS_ENABLED` | 生产环境为 false | 是否开放 `/docs` 与 OpenAPI 文档 |
| `CORS_ORIGINS` | 空 | 独立部署前端时允许的来源；同源部署无需设置 |

## Q&A

### Q: 如何开启/关闭请求体记录？

管理员在 **系统设置** 中配置日志记录的详细程度:

| 级别 | 记录内容 |
|------|----------|
| Base | 基本请求信息 |
| Headers | Base + 请求头 |
| Full | Headers + 请求体 |

### Q: 更新出问题如何回滚？

在 FastAPI Cloud 控制台选择最后一次成功部署。数据库变更不会随应用部署自动回滚，因此执行迁移前应使用数据库服务商的备份或时间点恢复能力。涉及删除字段的迁移应先部署不再读取该字段的代码，再单独执行迁移。

---

## 许可证

本项目采用 [Aether 非商业开源许可证](LICENSE)。允许个人学习、教育研究、非盈利组织及企业内部非盈利性质的使用；禁止用于盈利目的。商业使用请联系获取商业许可。

## 联系作者

<p align="center">
  <img src="docs/author/qq_qrcode.jpg" width="200" alt="QQ二维码">
  &nbsp;&nbsp;&nbsp;&nbsp;
  <img src="docs/author/qrcode_1770574997172.jpg" width="200" alt="QQ群二维码">
</p>

## Star History

[![Star History Chart](https://api.star-history.com/svg?repos=fawney19/Aether&type=Date)](https://star-history.com/#fawney19/Aether&Date)
