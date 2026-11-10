package metrics

import (
	"log/slog"
	"net/http"
	"strconv"
	"time"

	"github.com/prometheus/client_golang/prometheus"
	"github.com/prometheus/client_golang/prometheus/promauto"
)

var (
	// HttpRequestsTotal counts total HTTP requests processed by method, path, and HTTP status code.
	HttpRequestsTotal = promauto.NewCounterVec(
		prometheus.CounterOpts{
			Name: "http_requests_total",
			Help: "Total number of HTTP requests received.",
		},
		[]string{"method", "path", "status"},
	)

	// HttpErrorsTotal counts HTTP requests that resulted in 4xx or 5xx status codes.
	HttpErrorsTotal = promauto.NewCounterVec(
		prometheus.CounterOpts{
			Name: "http_errors_total",
			Help: "Total number of HTTP requests resulting in 4xx or 5xx errors.",
		},
		[]string{"method", "path", "status"},
	)

	// HttpRequestDurationSeconds tracks request duration in seconds.
	HttpRequestDurationSeconds = promauto.NewHistogramVec(
		prometheus.HistogramOpts{
			Name:    "http_request_duration_seconds",
			Help:    "Histogram of response latency in seconds.",
			Buckets: prometheus.DefBuckets,
		},
		[]string{"method", "path"},
	)
)

// responseWriterInterceptor intercepts WriteHeader to record HTTP status code.
type responseWriterInterceptor struct {
	http.ResponseWriter
	statusCode int
}

func (rw *responseWriterInterceptor) WriteHeader(code int) {
	rw.statusCode = code
	rw.ResponseWriter.WriteHeader(code)
}

// Middleware records Prometheus metrics and emits structured JSON access logs.
func Middleware(logger *slog.Logger) func(http.Handler) http.Handler {
	return func(next http.Handler) http.Handler {
		return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			start := time.Now()
			wrapped := &responseWriterInterceptor{
				ResponseWriter: w,
				statusCode:     http.StatusOK,
			}

			next.ServeHTTP(wrapped, r)

			duration := time.Since(start)
			statusStr := strconv.Itoa(wrapped.statusCode)
			path := r.URL.Path

			// Normalize metric paths to avoid cardinality explosions
			metricPath := path
			if metricPath == "" {
				metricPath = "/"
			}

			HttpRequestsTotal.WithLabelValues(r.Method, metricPath, statusStr).Inc()
			HttpRequestDurationSeconds.WithLabelValues(r.Method, metricPath).Observe(duration.Seconds())

			if wrapped.statusCode >= 400 {
				HttpErrorsTotal.WithLabelValues(r.Method, metricPath, statusStr).Inc()
			}

			// Structured access log
			logger.Info("http request completed",
				slog.String("method", r.Method),
				slog.String("path", path),
				slog.Int("status", wrapped.statusCode),
				slog.Duration("duration", duration),
				slog.String("remote_ip", r.RemoteAddr),
				slog.String("user_agent", r.UserAgent()),
			)
		})
	}
}
