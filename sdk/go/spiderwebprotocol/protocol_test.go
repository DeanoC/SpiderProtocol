package spiderwebprotocol

import "testing"

func TestValidateEnvelopeRejectsNullCorrelationFields(t *testing.T) {
	t.Parallel()

	controlErr := ValidateEnvelope(map[string]any{
		"channel": "control",
		"type":    "control.connect",
		"id":      nil,
	})
	assertProtocolErrorCode(t, controlErr, "invalid_id")

	acheronErr := ValidateEnvelope(map[string]any{
		"channel": "acheron",
		"type":    "acheron.t_attach",
		"tag":     nil,
		"fid":     1,
	})
	assertProtocolErrorCode(t, acheronErr, "invalid_tag")
}

func TestValidateEnvelopeAcceptsTypedCorrelationFields(t *testing.T) {
	t.Parallel()

	if err := ValidateEnvelope(map[string]any{
		"channel": "control",
		"type":    "control.connect",
		"id":      "req-1",
	}); err != nil {
		t.Fatalf("expected valid control envelope, got %v", err)
	}

	if err := ValidateEnvelope(map[string]any{
		"channel": "acheron",
		"type":    "acheron.t_attach",
		"tag":     2,
		"fid":     1,
	}); err != nil {
		t.Fatalf("expected valid acheron envelope, got %v", err)
	}
}

func assertProtocolErrorCode(t *testing.T, err error, want string) {
	t.Helper()

	if err == nil {
		t.Fatalf("expected protocol error %q, got nil", want)
	}

	protocolErr, ok := err.(*SpiderProtocolError)
	if !ok {
		t.Fatalf("expected SpiderProtocolError, got %T", err)
	}

	if protocolErr.Code != want {
		t.Fatalf("expected protocol error %q, got %q", want, protocolErr.Code)
	}
}
