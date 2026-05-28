package processor

import (
	"testing"

	"pollflow/poll-broker/internal/redis"
)

func TestValidateVote(t *testing.T) {
	tests := []struct {
		name      string
		vote      *redis.VotePayload
		expectErr bool
		errMsg    string
	}{
		{
			name: "valid vote with option 'a'",
			vote: &redis.VotePayload{
				PollID: 1,
				UserIP: "192.168.1.1",
				Option: "a",
			},
			expectErr: false,
		},
		{
			name: "valid vote with option 'b'",
			vote: &redis.VotePayload{
				PollID: 1,
				UserIP: "192.168.1.1",
				Option: "b",
			},
			expectErr: false,
		},
		{
			name: "invalid option 'c'",
			vote: &redis.VotePayload{
				PollID: 1,
				UserIP: "192.168.1.1",
				Option: "c",
			},
			expectErr: true,
			errMsg:    "invalid option",
		},
		{
			name: "invalid option 'A' (uppercase)",
			vote: &redis.VotePayload{
				PollID: 1,
				UserIP: "192.168.1.1",
				Option: "A",
			},
			expectErr: true,
			errMsg:    "invalid option",
		},
		{
			name: "empty option",
			vote: &redis.VotePayload{
				PollID: 1,
				UserIP: "192.168.1.1",
				Option: "",
			},
			expectErr: true,
			errMsg:    "invalid option",
		},
		{
			name: "invalid poll_id (zero)",
			vote: &redis.VotePayload{
				PollID: 0,
				UserIP: "192.168.1.1",
				Option: "a",
			},
			expectErr: true,
			errMsg:    "invalid poll_id",
		},
		{
			name: "invalid poll_id (negative)",
			vote: &redis.VotePayload{
				PollID: -1,
				UserIP: "192.168.1.1",
				Option: "a",
			},
			expectErr: true,
			errMsg:    "invalid poll_id",
		},
		{
			name: "empty user_ip",
			vote: &redis.VotePayload{
				PollID: 1,
				UserIP: "",
				Option: "a",
			},
			expectErr: true,
			errMsg:    "user_ip is empty",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// Create a processor (we don't need real db/redis for validation)
			p := &Processor{}

			err := p.validateVote(tt.vote)

			if tt.expectErr {
				if err == nil {
					t.Errorf("expected error containing '%s', got nil", tt.errMsg)
				} else if tt.errMsg != "" && !contains(err.Error(), tt.errMsg) {
					t.Errorf("expected error containing '%s', got '%s'", tt.errMsg, err.Error())
				}
			} else {
				if err != nil {
					t.Errorf("expected no error, got: %v", err)
				}
			}
		})
	}
}

// Helper function to check if string contains substring
func contains(s, substr string) bool {
	return len(s) >= len(substr) && (s == substr || len(s) > len(substr) &&
		(s[0:len(substr)] == substr || s[len(s)-len(substr):] == substr ||
			findInString(s, substr)))
}

func findInString(s, substr string) bool {
	for i := 0; i <= len(s)-len(substr); i++ {
		if s[i:i+len(substr)] == substr {
			return true
		}
	}
	return false
}
