package poller

import (
	"testing"
	"time"
)

func TestNew(t *testing.T) {
	tests := []struct {
		name     string
		interval time.Duration
	}{
		{
			name:     "10 second interval",
			interval: 10 * time.Second,
		},
		{
			name:     "1 minute interval",
			interval: 1 * time.Minute,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// Create poller with nil clients (we're just testing struct creation)
			p := New(nil, nil, tt.interval)

			if p == nil {
				t.Fatal("expected poller to be created, got nil")
			}

			if p.interval != tt.interval {
				t.Errorf("expected interval %v, got %v", tt.interval, p.interval)
			}

			if p.stopCh == nil {
				t.Error("expected stopCh to be initialized, got nil")
			}
		})
	}
}

func TestStop(t *testing.T) {
	p := New(nil, nil, 10*time.Second)

	// Call Stop - should close the channel
	p.Stop()

	// Verify channel is closed by trying to receive
	select {
	case _, ok := <-p.stopCh:
		if ok {
			t.Error("expected stopCh to be closed, but it's still open")
		}
	default:
		t.Error("expected stopCh to be closed and readable")
	}
}
