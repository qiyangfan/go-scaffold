# go-scaffold · Go 服务脚手架

单二进制 Go 服务的最小可运行骨架：复制、改 module 名、加 internal 包即开工。
与 hufu / muniu 的分层和门禁习惯一致，但不含业务域、数据库与鉴权。

## 技术栈

| 组件 | 版本 | 说明 |
| --- | --- | --- |
| Go | 1.27（mise 锚定） | 仅标准库，零运行时依赖 |
| log/slog | 标准库 | JSON 日志 + 请求访问日志 |
| golangci-lint | 2.15 | gofmt / vet / lint / tidy 全门禁 |
| 容器 | distroless static | CGO 关闭，非 root |

## 快速开始

```bash
mise install
make setup               # 安装 pre-commit hooks（uvx 可用时）
make run                 # http://127.0.0.1:3000
curl -s 127.0.0.1:3000/health/live
curl -s 127.0.0.1:3000/health/ready
```

环境变量：`PORT`（默认 3000）、`APP_ENV`、`LOG_LEVEL`（debug|info|warn|error）、
`SHUTDOWN_TIMEOUT`（默认 10s）。非法值启动即失败。

## 门禁

```bash
make check   # gofmt + vet + golangci + tidy + race/覆盖率 + 死代码 + 许可证 + 密钥 + 文档/配置 + build
```

CI 分三份：`ci.yml`（质量）、`security.yml`（密钥/依赖漏洞/SBOM/workflow lint）、
`codeql.yml`（SAST）。完整门禁矩阵、触发条件与负向验收证据见 [GATES.md](GATES.md)。

## 目录

```text
cmd/server/main.go        # 装配入口：配置、日志、信号、优雅停机
internal/config/          # 环境变量解析（非法即失败）
internal/server/          # 路由、中间件（request-id/访问日志）、健康检查
```

## 约定

- **依赖方向**：`cmd` → `internal`；`internal` 禁止反向 import `cmd`（depguard 执法）。
- **错误信封**：对外 JSON 统一 `{ code, message }`；未知路由 404 也走信封。
- **健康检查**：`live` 只看进程；`ready` 在接入数据库/缓存后聚合依赖探测，全绿才 200。
- **日志**：slog JSON；请求级字段含 `method/path/status/duration_ms/request_id`。
- **停机**：SIGINT/SIGTERM 触发 `http.Server.Shutdown`，超时受 `SHUTDOWN_TIMEOUT` 约束。
- **零依赖**：本种子只用标准库。接 PG 时加 `github.com/jackc/pgx/v5`，并在 ready 探针中 ping。

## 新建业务项目

```bash
cp -R ~/workspace/templates/go-scaffold ~/workspace/<新项目>
cd ~/workspace/<新项目>
rm -rf .git && git init
# 改 go.mod module、cmd/server 二进制名、README/AGENTS
# 同步 .golangci.yml 的 depguard 规则里的 module 路径（covercheck 会自动读取 go list -m）
```

业务模块放 `internal/<domain>/`，路由在 `internal/server.New` 里挂载；不要在
`cmd` 里写业务逻辑。
