#!/usr/bin/env bash
# 覆盖率门禁:聚合 total 下限 + 逐包下限 + 无测试包装配拦截。
# 逐包下限按 2026-11-21 实测向下取整冻结,只防回退、不设拔高目标;
# 未登记的包(含新增包)默认 50%,达不到就补测试,或在上方 floors 登记并写明理由。
# 用法:scripts/covercheck.sh [coverage.out](默认读仓库根 coverage.out)
set -euo pipefail

cd "$(dirname "$0")/.."
profile="${1:-coverage.out}"
module="$("${GO:-go}" list -m)"
total_floor=75
default_floor=50

# 包路径(去掉 module 前缀) → 下限
floors=(
  "internal/config=80" # 实测 89.3,防回退
  "internal/server=70" # 实测 78.9,防回退
)

# 允许无单测的装配入口:由构建与启动冒烟验证,不承载业务逻辑
no_test_ok="${module}/cmd/server"

expected=$(mktemp)
trap 'rm -f "$expected"' EXIT
# 同时取包内测试文件数:有测试但零可覆盖语句的包(如仅声明变量)不进剖面,不应误判为"无测试"
"${GO:-go}" list -f '{{.ImportPath}} {{len .TestGoFiles}} {{len .XTestGoFiles}}' ./... >"$expected"

rc=0
out=$(
  awk \
    -v module="$module" \
    -v total_floor="$total_floor" \
    -v default_floor="$default_floor" \
    -v floors="${floors[*]}" \
    -v no_test_ok="$no_test_ok" \
    -v expected_file="$expected" '
    BEGIN {
      n = split(floors, kv, " ")
      for (i = 1; i <= n; i++) { split(kv[i], pair, "="); floor_of[pair[1]] = pair[2] + 0 }
    }
    NR == 1 { next }
    {
      split($1, pos, ":")
      pkg = pos[1]
      sub(/\/[^\/]+$/, "", pkg)
      stmt[pkg] += $2
      if ($3 + 0 > 0) hit[pkg] += $2
      total += $2
      if ($3 + 0 > 0) covered += $2
    }
    END {
      bad = 0
      while ((getline line < expected_file) > 0) {
        n_f = split(line, f, " ")
        pkg = f[1]
        has_tests = (f[2] + 0) + (f[3] + 0)
        if (!(pkg in stmt)) {
          if (has_tests == 0 && pkg != no_test_ok) {
            printf "coverage gate FAIL: %s 无测试(未出现在覆盖率剖面)\n", pkg
            bad = 1
          }
          continue
        }
        short = pkg
        if (index(short, module "/") == 1) short = substr(short, length(module) + 2)
        floor = (short in floor_of) ? floor_of[short] : default_floor
        pct = 100 * hit[pkg] / stmt[pkg]
        if (pct + 0.0001 < floor) {
          printf "coverage gate FAIL: %s %.1f%% < %d%%\n", short, pct, floor
          bad = 1
        }
      }
      pct = 100 * covered / total
      if (pct + 0.0001 < total_floor) {
        printf "coverage gate FAIL: total %.1f%% < %d%%\n", pct, total_floor
        bad = 1
      } else {
        printf "coverage gate PASS: total %.1f%% (>= %d%%), 逐包下限已校验\n", pct, total_floor
      }
      exit bad
    }' "$profile"
) || rc=$?

if [ -n "$out" ]; then
  printf '%s\n' "$out"
fi
exit "$rc"
