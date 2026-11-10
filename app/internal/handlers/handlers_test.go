package handlers

import (
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"

	"github.com/MDALAMIN2526/DevOps-Engineer-Assessment/app/internal/config"
)

func testConfig() *config.Config {
	return &config.Config{
		Port:            ":8080",
		LogLevel:        "INFO",
		EnvironmentName: "test",
		AppVersion:      "1.0.0-test",
	}
}

func TestRootEndpoint(t *testing.T) {
	cfg := testConfig()
	router := NewRouter(cfg)

	req := httptest.NewRequest(http.MethodGet, "/", nil)
	rr := httptest.NewRecorder()

	router.ServeHTTP(rr, req)

	if rr.Code != http.StatusOK {
		t.Fatalf("expected status %d, got %d", http.StatusOK, rr.Code)
	}

	contentType := rr.Header().Get("Content-Type")
	if !strings.Contains(contentType, "application/json") {
		t.Errorf("expected Content-Type application/json, got %s", contentType)
	}

	var resp RootResponse
	if err := json.NewDecoder(rr.Body).Decode(&resp); err != nil {
		t.Fatalf("failed to decode JSON response: %v", err)
	}

	expectedMsg := "Hello from DevOps Task!"
	if resp.Message != expectedMsg {
		t.Errorf("expected message %q, got %q", expectedMsg, resp.Message)
	}

	expectedStatus := "running"
	if resp.Status != expectedStatus {
		t.Errorf("expected status %q, got %q", expectedStatus, resp.Status)
	}

	if resp.Version != cfg.AppVersion {
		t.Errorf("expected version %q, got %q", cfg.AppVersion, resp.Version)
	}
}

func TestHealthEndpoint(t *testing.T) {
	cfg := testConfig()
	router := NewRouter(cfg)

	req := httptest.NewRequest(http.MethodGet, "/health", nil)
	rr := httptest.NewRecorder()

	router.ServeHTTP(rr, req)

	if rr.Code != http.StatusOK {
		t.Fatalf("expected status %d, got %d", http.StatusOK, rr.Code)
	}

	var resp HealthResponse
	if err := json.NewDecoder(rr.Body).Decode(&resp); err != nil {
		t.Fatalf("failed to decode JSON response: %v", err)
	}

	if resp.Status != "healthy" {
		t.Errorf("expected status 'healthy', got %q", resp.Status)
	}

	if resp.Version != cfg.AppVersion {
		t.Errorf("expected version %q, got %q", cfg.AppVersion, resp.Version)
	}

	if resp.Environment != cfg.EnvironmentName {
		t.Errorf("expected environment %q, got %q", cfg.EnvironmentName, resp.Environment)
	}
}

func TestMetricsEndpoint(t *testing.T) {
	cfg := testConfig()
	router := NewRouter(cfg)

	req := httptest.NewRequest(http.MethodGet, "/metrics", nil)
	rr := httptest.NewRecorder()

	router.ServeHTTP(rr, req)

	if rr.Code != http.StatusOK {
		t.Fatalf("expected status %d, got %d", http.StatusOK, rr.Code)
	}

	body := rr.Body.String()
	if !strings.Contains(body, "http_requests_total") && !strings.Contains(body, "go_info") {
		t.Errorf("expected metrics output containing http_requests_total or go_info, got: %s", body)
	}
}
