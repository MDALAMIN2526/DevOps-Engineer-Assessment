package config

import (
	"os"
	"testing"
)

func TestConfigLoadDefaults(t *testing.T) {
	os.Unsetenv("PORT")
	os.Unsetenv("LOG_LEVEL")
	os.Unsetenv("ENVIRONMENT")
	os.Unsetenv("APP_VERSION")

	cfg := Load()

	if cfg.Port != ":8080" {
		t.Errorf("expected default port :8080, got %s", cfg.Port)
	}
	if cfg.LogLevel != "INFO" {
		t.Errorf("expected default log level INFO, got %s", cfg.LogLevel)
	}
	if cfg.EnvironmentName != "development" {
		t.Errorf("expected default environment development, got %s", cfg.EnvironmentName)
	}
	if cfg.AppVersion != "1.0.0" {
		t.Errorf("expected default version 1.0.0, got %s", cfg.AppVersion)
	}
}

func TestConfigLoadCustomEnv(t *testing.T) {
	os.Setenv("PORT", "9090")
	os.Setenv("LOG_LEVEL", "debug")
	os.Setenv("ENVIRONMENT", "production")
	os.Setenv("APP_VERSION", "2.1.0")

	defer func() {
		os.Unsetenv("PORT")
		os.Unsetenv("LOG_LEVEL")
		os.Unsetenv("ENVIRONMENT")
		os.Unsetenv("APP_VERSION")
	}()

	cfg := Load()

	if cfg.Port != ":9090" {
		t.Errorf("expected port :9090, got %s", cfg.Port)
	}
	if cfg.LogLevel != "DEBUG" {
		t.Errorf("expected log level DEBUG, got %s", cfg.LogLevel)
	}
	if cfg.EnvironmentName != "production" {
		t.Errorf("expected environment production, got %s", cfg.EnvironmentName)
	}
	if cfg.AppVersion != "2.1.0" {
		t.Errorf("expected version 2.1.0, got %s", cfg.AppVersion)
	}
}
