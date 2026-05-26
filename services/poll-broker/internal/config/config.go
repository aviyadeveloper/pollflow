package config

import (
	"fmt"
	"net/url"
	"os"
	"strconv"
)

// Config holds all configuration for the poll-broker service
type Config struct {
	Database DatabaseConfig
	Redis    RedisConfig
}

// DatabaseConfig holds PostgreSQL connection settings
type DatabaseConfig struct {
	Host     string
	Port     int
	Name     string
	User     string
	Password string
}

// RedisConfig holds Redis connection settings
type RedisConfig struct {
	Host string
	Port int
}

// Load reads configuration from environment variables
func Load() (*Config, error) {
	dbPort, err := getEnvAsIntRequired("DB_PORT")
	if err != nil {
		return nil, err
	}

	redisPort, err := getEnvAsIntRequired("REDIS_PORT")
	if err != nil {
		return nil, err
	}

	cfg := &Config{
		Database: DatabaseConfig{
			Host:     os.Getenv("DB_HOST"),
			Port:     dbPort,
			Name:     os.Getenv("DB_NAME"),
			User:     os.Getenv("DB_USER"),
			Password: os.Getenv("DB_PASSWORD"),
		},
		Redis: RedisConfig{
			Host: os.Getenv("REDIS_HOST"),
			Port: redisPort,
		},
	}

	if err := cfg.Validate(); err != nil {
		return nil, fmt.Errorf("config validation failed: %w", err)
	}

	return cfg, nil
}

// Validate checks that required configuration values are present
func (c *Config) Validate() error {
	if c.Database.Host == "" {
		return fmt.Errorf("DB_HOST environment variable is required")
	}
	if c.Database.Name == "" {
		return fmt.Errorf("DB_NAME environment variable is required")
	}
	if c.Database.User == "" {
		return fmt.Errorf("DB_USER environment variable is required")
	}
	if c.Database.Password == "" {
		return fmt.Errorf("DB_PASSWORD environment variable is required")
	}
	if c.Database.Port <= 0 {
		return fmt.Errorf("DB_PORT must be a positive integer")
	}
	if c.Redis.Host == "" {
		return fmt.Errorf("REDIS_HOST environment variable is required")
	}
	if c.Redis.Port <= 0 {
		return fmt.Errorf("REDIS_PORT must be a positive integer")
	}
	return nil
}

// DatabaseURL returns a PostgreSQL connection string
// Username and password are URL-encoded to handle special characters
func (c *Config) DatabaseURL() string {
	return fmt.Sprintf(
		"postgres://%s:%s@%s:%d/%s?sslmode=require",
		url.PathEscape(c.Database.User),
		url.PathEscape(c.Database.Password),
		c.Database.Host,
		c.Database.Port,
		c.Database.Name,
	)
}

// RedisAddr returns Redis address in host:port format
func (c *Config) RedisAddr() string {
	return fmt.Sprintf("%s:%d", c.Redis.Host, c.Redis.Port)
}

// Helper functions

func getEnvAsIntRequired(key string) (int, error) {
	valueStr := os.Getenv(key)
	if valueStr == "" {
		return 0, fmt.Errorf("%s environment variable is required", key)
	}
	value, err := strconv.Atoi(valueStr)
	if err != nil {
		return 0, fmt.Errorf("%s must be a valid integer: %w", key, err)
	}
	return value, nil
}
