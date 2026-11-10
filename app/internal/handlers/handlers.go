package handlers

import (
	"encoding/json"
	"net/http"
	"time"

	"github.com/MDALAMIN2526/DevOps-Engineer-Assessment/app/internal/config"
	"github.com/prometheus/client_golang/prometheus/promhttp"
)

var startTime = time.Now()

// RootResponse represents response for GET /
type RootResponse struct {
	Message string `json:"message"`
	Status  string `json:"status"`
	Version string `json:"version"`
}

// HealthResponse represents response for GET /health
type HealthResponse struct {
	Status        string `json:"status"`
	UptimeSeconds int64  `json:"uptime_seconds"`
	Version       string `json:"version"`
	Environment   string `json:"environment"`
}

// NewRouter constructs the HTTP handler router with configured endpoints.
func NewRouter(cfg *config.Config) *http.ServeMux {
	mux := http.NewServeMux()

	mux.HandleFunc("GET /{$}", RootHandler(cfg))
	mux.HandleFunc("GET /health", HealthHandler(cfg))
	mux.Handle("GET /metrics", promhttp.Handler())

	return mux
}

// RootHandler handles GET / requests.
func RootHandler(cfg *config.Config) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Content-Type", "application/json")
		w.WriteHeader(http.StatusOK)

		resp := RootResponse{
			Message: "Hello from DevOps Task!",
			Status:  "running",
			Version: cfg.AppVersion,
		}

		_ = json.NewEncoder(w).Encode(resp)
	}
}

// HealthHandler handles GET /health liveness and readiness probe requests.
func HealthHandler(cfg *config.Config) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Content-Type", "application/json")
		w.WriteHeader(http.StatusOK)

		resp := HealthResponse{
			Status:        "healthy",
			UptimeSeconds: int64(time.Since(startTime).Seconds()),
			Version:       cfg.AppVersion,
			Environment:   cfg.EnvironmentName,
		}

		_ = json.NewEncoder(w).Encode(resp)
	}
}
