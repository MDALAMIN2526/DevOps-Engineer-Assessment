package metrics

import (
	"bytes"
	"log/slog"
	"net/http"
	"net/http/httptest"
	"testing"
)

func TestMetricsMiddleware(t *testing.T) {
	buf := new(bytes.Buffer)
	logger := slog.New(slog.NewJSONHandler(buf, nil))

	dummyHandler := http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.URL.Path == "/error" {
			w.WriteHeader(http.StatusInternalServerError)
			_, _ = w.Write([]byte("error"))
			return
		}
		w.WriteHeader(http.StatusOK)
		_, _ = w.Write([]byte("ok"))
	})

	mw := Middleware(logger)
	handler := mw(dummyHandler)

	// Test 200 OK
	reqOk := httptest.NewRequest(http.MethodGet, "/test", nil)
	rrOk := httptest.NewRecorder()
	handler.ServeHTTP(rrOk, reqOk)

	if rrOk.Code != http.StatusOK {
		t.Fatalf("expected status 200, got %d", rrOk.Code)
	}

	// Test 500 Error
	reqErr := httptest.NewRequest(http.MethodGet, "/error", nil)
	rrErr := httptest.NewRecorder()
	handler.ServeHTTP(rrErr, reqErr)

	if rrErr.Code != http.StatusInternalServerError {
		t.Fatalf("expected status 500, got %d", rrErr.Code)
	}

	// Verify structured log output contains JSON logs
	logs := buf.String()
	if !bytes.Contains(buf.Bytes(), []byte("http request completed")) {
		t.Errorf("expected structured log message 'http request completed', got: %s", logs)
	}
}
