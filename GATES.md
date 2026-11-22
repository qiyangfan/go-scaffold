# GATES — 门禁矩阵、触发条件与负向验收

本仓是复制型种子：门禁按"实际具备的形态面"配置。新增形态时按下表触发器补门禁，
不要预装无法真跑的检查（纸面门禁）。

## 本地 / CI 对应

```bash
make check    # gofmt + vet + golangci + tidy + race/覆盖率 + 死代码 + 许可证 + 密钥 + 文档 + 配置 + build
```

CI 分三份：`ci.yml`（质量）、`security.yml`（密钥/依赖漏洞/SBOM/workflow lint）、
`codeql.yml`（SAST）。

| 门禁 | 命令 | 本地 | CI | 负向验收（2026-11-21） |
|---|---|---|---|---|
| gofmt | `make fmt-check` | ✅ | ci.yml | ✅ 未格式化函数 → 红 |
| go vet | `make vet` | ✅ | ci.yml | ✅ `Printf("%d", "x")` → 红 |
| golangci-lint（含 gosec/depguard） | `make lint` | ✅ | ci.yml | ✅ `math/rand` 弱随机（G404）→ 红 |
| 覆盖率（聚合 75 / 逐包 50 + 登记水位） | `scripts/covercheck.sh` | ✅ | ci.yml | ✅ 0% 伪剖面 → 红 |
| 死代码 | `scripts/deadcodecheck.sh` | ✅ | ci.yml | ✅ 未调用函数 → 红 |
| 许可证 allowlist | `scripts/licensecheck.sh` | `go-licenses` 存在时 | ci.yml | ✅ 临时 MIT 依赖 + Apache-only 白名单 → 红 |
| 密钥（gitleaks） | `gitleaks dir .` / `detect` 全历史 | ✅ | security.yml | ✅ 植入假 AKIA 凭据 → 红 |
| 依赖漏洞 | `govulncheck ./...` | -（security 同款） | security.yml | 需漏洞库联网，CI 实证 |
| SBOM | `syft dir:. -c .syft.yaml` | - | security.yml（artifact） | 正向生成在 CI 执行 |
| 提交信息 | `scripts/commitcheck.sh --file` | ✅ pre-commit | - | ✅ 非法标题 → 红 |
| Workflow lint | `actionlint` | ✅ | security.yml | ✅ 非法 YAML → 红 |
| YAML lint | `uvx yamllint -c .yamllint.yml .github` | ✅ | security.yml | ✅（与 actionlint 同文件） |
| Markdown lint | `markdownlint-cli2` | ✅ | ci.yml | ✅ 跳级标题（MD001）→ 红 |
| Dockerfile lint | `hadolint Containerfile` | ✅ | -（镜像构建时） | ✅ 未固定 apt 版本 → 红 |
| SAST（CodeQL） | workflow | - | codeql.yml | 需远端仓库，建仓后首次运行实证 |

## 触发矩阵（新增形态时补）

| 新增形态 | 必须补的门禁 |
|---|---|
| 接入 PostgreSQL/Redis | 真实依赖的集成测试（Testcontainers 或 compose）、ready 探针改为真实探测、连接泄漏检查 |
| HTTP 契约 | OpenAPI 重生成 diff（`git diff --exit-code`）+ oasdiff |
| 消息队列/定时任务 | 幂等与重放测试、消费者契约测试 |
| 发布镜像 | trivy image（HIGH/CRITICAL，`--ignore-unfixed`）+ 基础镜像钉 sha256 |
| CGO/性能热点 | benchmark + 分配/延迟基线；pgo 按需 |

## 平台侧（建 GitHub 远端后）

- 分支保护：`secrets`、`deps`、`sbom`、`workflows`、`codeql`、`go` 设为 required。
- 必须按首跑展开后的真实 job 名设置，禁止猜名字。
- CodeQL 首次运行后再设 required；私库免费版不支持分支保护时，如实记录为纸面状态。

## 抑制纪律

- 当前零人工抑制：golangci 无 `nolint`，覆盖率无下调，overrides 无。
- `cmd/server` 无单测属装配入口豁免（`covercheck.sh` 的 `no_test_ok`），由构建与启动冒烟验证。
- 新增抑制必须写原因、负责人、到期日；到期未复审即视为门禁失效。
