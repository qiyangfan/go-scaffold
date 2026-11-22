# AGENTS.md — go-scaffold 执行者工作契约

本仓是**业务无关的 Go 服务种子**。任何改动都必须保持「复制即用」：
复制后只改 module 名、二进制名与连接串就能开工。

## 定位

- 提供：标准库 HTTP 服务骨架、配置 fail-fast、JSON 日志与访问日志、request-id、
  健康检查、优雅停机、单二进制容器构建、全量门禁与 CI。
- 不提供：业务实体、数据库、鉴权、限流、消息队列、微服务拆分。
  这些属于业务项目或对应平台仓，不要塞进本仓。

## 硬性纪律

1. **依赖方向**：`cmd` 只做装配，业务逻辑放 `internal`；`internal` 禁止 import `cmd`
   （golangci depguard 执法）。
2. **配置单源**：环境变量只经 `internal/config` 读取；新增变量必须同步 README，
   非法值返回错误，不允许静默回落。
3. **错误信封**：对外错误统一 `{ code, message }`；禁止直接 `http.Error` 输出裸文本
   （健康检查与探测路径除外）。
4. **零第三方运行时依赖**：引入依赖必须写明用途与替代方案；不要为「可能用到」预置。
5. **门禁不可绕过**：`make check` 与 CI 同款；gofmt、vet、lint、tidy 任一红都不得合入。

## 分层

```text
cmd/server ──装配──> internal/server ──> internal/<domain>
```

- `internal/server`：HTTP 协议层（路由、中间件、状态码）。
- `internal/<domain>`：业务用例与端口；领域逻辑不得直接依赖 `net/http` 细节。
- 业务入口建议以 `func Register(mux *http.ServeMux, deps Deps)` 形式挂载。

## 测试

- 测试与被测包同目录；HTTP 契约用 `httptest`，不得起真实监听。
- 新增路由必须补状态码 + 响应形状断言。
- `make test` 固定 `-race -shuffle=on`，不允许只跑单包就宣称通过。
