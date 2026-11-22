package server

import (
	"context"
	"encoding/json"
	"io"
	"log/slog"
	"net/http"
	"net/http/httptest"
	"testing"
	"time"

	"github.com/solvela/go-scaffold/internal/config"
)

func newTestServer(t *testing.T) *Server {
	t.Helper()
	cfg := config.Config{Addr: ":0", Env: "test", ShutdownTimeout: time.Second}
	return New(cfg, slog.New(slog.NewTextHandler(io.Discard, nil)))
}

func doRequest(t *testing.T, srv *Server, method, path string) *httptest.ResponseRecorder {
	t.Helper()
	rec := httptest.NewRecorder()
	srv.Handler().ServeHTTP(rec, httptest.NewRequestWithContext(context.Background(), method, path, nil))
	return rec
}

func TestHealthLive(t *testing.T) {
	rec := doRequest(t, newTestServer(t), http.MethodGet, "/health/live")

	if rec.Code != http.StatusOK {
		t.Fatalf("status = %d, want 200", rec.Code)
	}
	var body map[string]string
	if err := json.Unmarshal(rec.Body.Bytes(), &body); err != nil {
		t.Fatalf("decode body: %v", err)
	}
	if body["status"] != "up" {
		t.Errorf("status field = %q, want up", body["status"])
	}
}

func TestHealthReady(t *testing.T) {
	rec := doRequest(t, newTestServer(t), http.MethodGet, "/health/ready")

	if rec.Code != http.StatusOK {
		t.Fatalf("status = %d, want 200", rec.Code)
	}
}

func TestUnknownRouteReturnsEnvelope(t *testing.T) {
	rec := doRequest(t, newTestServer(t), http.MethodGet, "/missing")

	if rec.Code != http.StatusNotFound {
		t.Fatalf("status = %d, want 404", rec.Code)
	}
	var body envelope
	if err := json.Unmarshal(rec.Body.Bytes(), &body); err != nil {
		t.Fatalf("decode body: %v", err)
	}
	if body.Code != "NOT_FOUND" {
		t.Errorf("code = %q, want NOT_FOUND", body.Code)
	}
}

func TestRequestIDPropagation(t *testing.T) {
	srv := newTestServer(t)
	rec := httptest.NewRecorder()
	req := httptest.NewRequestWithContext(context.Background(), http.MethodGet, "/health/live", nil)
	req.Header.Set("X-Request-Id", "trace-123")

	srv.Handler().ServeHTTP(rec, req)

	if got := rec.Header().Get("X-Request-Id"); got != "trace-123" {
		t.Errorf("X-Request-Id = %q, want trace-123", got)
	}
}
