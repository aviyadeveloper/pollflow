package logger

import (
	"os"

	"github.com/sirupsen/logrus"
)

var Log *logrus.Logger

// LogFields is an alias for logrus.Fields for convenience
type LogFields = logrus.Fields

// Initialize sets up structured JSON logging for the application
func Initialize() {
	Log = logrus.New()

	// Output to stdout (container best practice)
	Log.SetOutput(os.Stdout)

	// JSON formatter for structured logging
	Log.SetFormatter(&logrus.JSONFormatter{
		TimestampFormat: "2006-01-02T15:04:05.000Z07:00",
		FieldMap: logrus.FieldMap{
			logrus.FieldKeyTime:  "timestamp",
			logrus.FieldKeyLevel: "level",
			logrus.FieldKeyMsg:   "message",
		},
	})

	// Set log level based on environment (default: INFO)
	logLevel := os.Getenv("LOG_LEVEL")
	switch logLevel {
	case "DEBUG":
		Log.SetLevel(logrus.DebugLevel)
	case "WARN":
		Log.SetLevel(logrus.WarnLevel)
	case "ERROR":
		Log.SetLevel(logrus.ErrorLevel)
	default:
		Log.SetLevel(logrus.InfoLevel)
	}

	// Add service name to all logs
	Log = Log.WithField("service", "poll-broker").Logger
}

// WithFields creates a new logger entry with additional context fields
func WithFields(fields logrus.Fields) *logrus.Entry {
	return Log.WithFields(fields)
}

// WithEvent creates a logger entry with event context
func WithEvent(event string) *logrus.Entry {
	return Log.WithField("event", event)
}
