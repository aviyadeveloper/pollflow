package logger

import (
	"os"

	"github.com/afiskon/promtail-client/promtail"
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

	// Add Loki hook if URL is configured
	lokiURL := os.Getenv("LOKI_URL")
	if lokiURL != "" {
		conf := promtail.ClientConfig{
			PushURL:            lokiURL + "/loki/api/v1/push",
			Labels:             "{service=\"poll-broker\",environment=\"" + getEnv("APP_ENV", "development") + "\"}",
			BatchWait:          2000, // 2 seconds
			BatchEntriesNumber: 10000,
			SendLevel:          promtail.INFO,
			PrintLevel:         promtail.ERROR,
		}

		loki, err := promtail.NewClientProto(conf)
		if err != nil {
			Log.WithError(err).Warn("Failed to initialize Loki client, continuing with stdout only")
		} else {
			Log.AddHook(&LokiHook{client: loki})
			Log.Info("Loki log shipping enabled")
		}
	}
}

// LokiHook sends logs to Loki
type LokiHook struct {
	client promtail.Client
}

func (hook *LokiHook) Fire(entry *logrus.Entry) error {
	line, err := entry.String()
	if err != nil {
		return err
	}

	level := entry.Level.String()
	hook.client.Infof("%s: %s", level, line)
	return nil
}

func (hook *LokiHook) Levels() []logrus.Level {
	return logrus.AllLevels
}

func getEnv(key, fallback string) string {
	if value := os.Getenv(key); value != "" {
		return value
	}
	return fallback
}

// WithFields creates a new logger entry with additional context fields
func WithFields(fields logrus.Fields) *logrus.Entry {
	return Log.WithFields(fields)
}

// WithEvent creates a logger entry with event context
func WithEvent(event string) *logrus.Entry {
	return Log.WithField("event", event)
}
