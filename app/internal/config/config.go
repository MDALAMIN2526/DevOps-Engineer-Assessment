package config

import (
	"os"
	"strings"
)

// Config holds the application configuration loaded from environment variables.
type Config struct {
	Port            string `json:"port"`
	LogLevel        string `json:"log_level"`
	EnvironmentName string `json:"environment"`
	AppVersion      string `json:"version"`
}

// Load reads configuration from environment variables with sensible defaults.
func Load() *Config {
	port := getEnv("PORT", "8080")
	if !strings.HasPrefix(port, ":") {
		port = ":" + port
	}

	return &Config{
		Port:            port,
		LogLevel:        strings.ToUpper(getEnv("LOG_LEVEL", "INFO")),
		EnvironmentName: getEnv("ENVIRONMENT", "development"),
		AppVersion:      getEnv("APP_VERSION", "1.0.0"),
	}
}

func getEnv(key, defaultVal string) string {
	if val, exists := os.LookupEnv(key); exists && strings.TrimSpace(val) != "" {
		return strings.TrimSpace(val)
	}
	return defaultVal
}
