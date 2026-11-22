package config

import (
	"fmt"
	"log/slog"
	"os"
	"strconv"
	"strings"
	"time"
)

// Config 是进程启动所需的全部外部输入；缺失或非法时拒绝启动。
type Config struct {
	Env             string
	Addr            string
	LogLevel        slog.Level
	ShutdownTimeout time.Duration
}

const defaultShutdownTimeout = 10 * time.Second

// Load 从环境变量解析配置，任何非法值都返回错误（fail-fast）。
func Load() (Config, error) {
	port, err := parsePort(envOr("PORT", "3000"))
	if err != nil {
		return Config{}, err
	}

	level, err := parseLevel(envOr("LOG_LEVEL", "info"))
	if err != nil {
		return Config{}, err
	}

	timeout := defaultShutdownTimeout
	if raw := strings.TrimSpace(os.Getenv("SHUTDOWN_TIMEOUT")); raw != "" {
		parsed, parseErr := time.ParseDuration(raw)
		if parseErr != nil {
			return Config{}, fmt.Errorf("parse SHUTDOWN_TIMEOUT %q: %w", raw, parseErr)
		}
		if parsed <= 0 {
			return Config{}, fmt.Errorf("SHUTDOWN_TIMEOUT must be positive, got %q", raw)
		}
		timeout = parsed
	}

	return Config{
		Env:             envOr("APP_ENV", "development"),
		Addr:            fmt.Sprintf(":%d", port),
		LogLevel:        level,
		ShutdownTimeout: timeout,
	}, nil
}

func envOr(key, fallback string) string {
	if value := strings.TrimSpace(os.Getenv(key)); value != "" {
		return value
	}
	return fallback
}

func parsePort(raw string) (int, error) {
	port, err := strconv.Atoi(raw)
	if err != nil || port < 1 || port > 65535 {
		return 0, fmt.Errorf("invalid PORT %q: must be an integer in 1-65535", raw)
	}
	return port, nil
}

func parseLevel(raw string) (slog.Level, error) {
	switch strings.ToLower(raw) {
	case "debug":
		return slog.LevelDebug, nil
	case "info":
		return slog.LevelInfo, nil
	case "warn":
		return slog.LevelWarn, nil
	case "error":
		return slog.LevelError, nil
	default:
		return 0, fmt.Errorf("invalid LOG_LEVEL %q: want debug|info|warn|error", raw)
	}
}
