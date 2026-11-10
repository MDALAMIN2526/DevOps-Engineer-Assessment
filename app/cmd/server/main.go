package main

import (
	"context"
	"errors"
	"log/slog"
	"net/http"
	"os"
	"os/signal"
	"syscall"
	"time"

	"github.com/MDALAMIN2526/DevOps-Engineer-Assessment/app/internal/config"
	"github.com/MDALAMIN2526/DevOps-Engineer-Assessment/app/internal/handlers"
	"github.com/MDALAMIN2526/DevOps-Engineer-Assessment/app/internal/metrics"
)

func main() {
	cfg := config.Load()

	// Parse log level
	var logLevel slog.Level
	switch cfg.LogLevel {
	case "DEBUG":
		logLevel = slog.LevelDebug
	case "WARN":
		logLevel = slog.LevelWarn
	case "ERROR":
		logLevel = slog.LevelError
	default:
		logLevel = slog.LevelInfo
	}

	// Initialize structured JSON logging to stdout
	logger := slog.New(slog.NewJSONHandler(os.Stdout, &slog.HandlerOptions{
		Level: logLevel,
	})).With(
		slog.String("service", "devops-assessment-service"),
		slog.String("env", cfg.EnvironmentName),
		slog.String("version", cfg.AppVersion),
	)

	slog.SetDefault(logger)

	logger.Info("starting application server",
		slog.String("port", cfg.Port),
		slog.String("log_level", cfg.LogLevel),
		slog.String("environment", cfg.EnvironmentName),
		slog.String("version", cfg.AppVersion),
	)

	router := handlers.NewRouter(cfg)
	handlerWithMiddleware := metrics.Middleware(logger)(router)

	srv := &http.Server{
		Addr:              cfg.Port,
		Handler:           handlerWithMiddleware,
		ReadHeaderTimeout: 5 * time.Second,
		ReadTimeout:       15 * time.Second,
		WriteTimeout:      15 * time.Second,
		IdleTimeout:       60 * time.Second,
	}

	// Channel to listen for errors coming from the listener.
	serverErrors := make(chan error, 1)

	go func() {
		logger.Info("http server listening", slog.String("addr", srv.Addr))
		if err := srv.ListenAndServe(); err != nil && !errors.Is(err, http.ErrServerClosed) {
			serverErrors <- err
		}
	}()

	// Channel to listen for shutdown signals
	shutdownSignal := make(chan os.Signal, 1)
	signal.Notify(shutdownSignal, os.Interrupt, syscall.SIGTERM, syscall.SIGINT)

	select {
	case err := <-serverErrors:
		logger.Error("server listener error encountered", slog.String("error", err.Error()))
		os.Exit(1)

	case sig := <-shutdownSignal:
		logger.Info("shutdown signal received; commencing graceful shutdown",
			slog.String("signal", sig.String()),
		)

		ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
		defer cancel()

		if err := srv.Shutdown(ctx); err != nil {
			logger.Error("server forced to shutdown due to error", slog.String("error", err.Error()))
			if closeErr := srv.Close(); closeErr != nil {
				logger.Error("failed to close server listeners", slog.String("error", closeErr.Error()))
			}
			os.Exit(1)
		}

		logger.Info("graceful shutdown completed successfully")
	}
}
