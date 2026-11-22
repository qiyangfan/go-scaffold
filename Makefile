.PHONY: setup check fmt-check vet lint tidy-check test cover deadcode licenses secrets markdownlint infra-lint build run

GO ?= go
GOLANGCI ?= golangci-lint
BIN := bin/server

setup:
	@if command -v uvx >/dev/null 2>&1; then uvx pre-commit@4.0.0 install --install-hooks; else echo "[setup] uvx 未安装,跳过 pre-commit hooks(CI 仍执行全部门禁)"; fi

## check: 全量门禁（格式、vet、lint、依赖整洁、race/覆盖率、死代码、许可证、密钥、文档、配置、构建）
check: fmt-check vet lint tidy-check test deadcode licenses secrets markdownlint infra-lint build

fmt-check:
	@out="$$(gofmt -l .)"; if [ -n "$$out" ]; then echo "$$out"; echo "[fmt-check] gofmt 未通过"; exit 1; fi

vet:
	$(GO) vet ./...

lint:
	@if command -v $(GOLANGCI) >/dev/null 2>&1; then $(GOLANGCI) run ./...; else echo "[lint] golangci-lint 未安装,跳过"; fi

tidy-check:
	$(GO) mod tidy -diff

test:
	# cmd 是装配入口，由构建与启动冒烟验证，不纳入逐包覆盖率口径
	$(GO) test -race -shuffle=on -covermode=atomic -coverprofile=coverage.out ./internal/...
	./scripts/covercheck.sh coverage.out

cover:
	$(GO) tool cover -html=coverage.out -o coverage.html

deadcode:
	@if command -v deadcode >/dev/null 2>&1; then ./scripts/deadcodecheck.sh; else echo "[deadcode] deadcode 未安装,跳过"; fi

licenses:
	@if command -v go-licenses >/dev/null 2>&1; then ./scripts/licensecheck.sh; else echo "[licenses] go-licenses 未安装,跳过"; fi

secrets:
	@if command -v gitleaks >/dev/null 2>&1; then gitleaks dir . --redact --exit-code 1; else echo "[secrets] gitleaks 未安装,跳过"; fi

markdownlint:
	npx --yes markdownlint-cli2@0.24.1

infra-lint:
	@if command -v actionlint >/dev/null 2>&1; then actionlint; else echo "[infra-lint] actionlint 未安装,跳过"; fi
	@if command -v hadolint >/dev/null 2>&1; then hadolint Containerfile; else echo "[infra-lint] hadolint 未安装,跳过"; fi
	@if command -v uvx >/dev/null 2>&1; then uvx yamllint==1.38.0 -c .yamllint.yml .github; else echo "[infra-lint] uvx 未安装,跳过 yamllint"; fi

build:
	$(GO) build -trimpath -o $(BIN) ./cmd/server

run:
	$(GO) run ./cmd/server
