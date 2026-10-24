package client

import (
	"encoding/json"
	"fmt"
	"io"

	"github.com/spoke-sh/transit/sdks/go/internal/nativeclient"
)

// ErrorKind can be used with errors.Is. Inspect *Error with errors.As for detail.
type ErrorKind string

func (kind ErrorKind) Error() string { return string(kind) }

const (
	ErrInvalidArgument       ErrorKind = "invalid argument"
	ErrBusy                  ErrorKind = "client busy"
	ErrClosed                ErrorKind = "client closed"
	ErrIncompatibleNative    ErrorKind = "incompatible native library"
	ErrUnsupportedCapability ErrorKind = "unsupported capability"
	ErrRejected              ErrorKind = "operation rejected"
	ErrAccessDenied          ErrorKind = "access denied"
	ErrStaleOwnership        ErrorKind = "stale ownership"
	ErrProcessRetired        ErrorKind = "process retired"
	ErrHistoryUnavailable    ErrorKind = "history unavailable"
	ErrReadFailed            ErrorKind = "read failed"
	ErrUnknownOutcome        ErrorKind = "unknown operation outcome"
	ErrOutOfMemory           ErrorKind = "native allocation failed"
)

// Error preserves the primary outcome independently of optional diagnostics.
// Error text and fmt output omit response payloads, recovery bytes and detail.
type Error struct {
	Kind              ErrorKind
	Phase             string
	NativeStatus      *uint32
	Code              string
	DiagnosticInvalid bool
	diagnostic        json.RawMessage
	cause             error
}

func failure(kind ErrorKind, phase string) *Error { return &Error{Kind: kind, Phase: phase} }
func (e *Error) Error() string                    { return fmt.Sprintf("Transit %s during %s", e.Kind, e.Phase) }
func (e *Error) Format(state fmt.State, _ rune)   { io.WriteString(state, e.Error()) }
func (e *Error) Is(target error) bool             { return target == e.Kind }
func (e *Error) Unwrap() error                    { return e.cause }
func (e *Error) Diagnostic() json.RawMessage      { return append(json.RawMessage(nil), e.diagnostic...) }

// DispatchError retains recovery material when a mutation's outcome is unknown.
// errors.Is can match both ErrUnknownOutcome and the context cancellation cause.
type DispatchError struct {
	Cause    error
	recovery []byte
}

func (e *DispatchError) Error() string                  { return e.Cause.Error() }
func (e *DispatchError) Unwrap() error                  { return e.Cause }
func (e *DispatchError) Recovery() []byte               { return append([]byte(nil), e.recovery...) }
func (e *DispatchError) Format(state fmt.State, _ rune) { io.WriteString(state, e.Error()) }

func nativeError(result nativeclient.Result, phase string) *Error {
	kind := ErrInvalidArgument
	switch result.Status {
	case nativeclient.StatusOutOfMemory:
		kind = ErrOutOfMemory
	case nativeclient.StatusRejected, nativeclient.StatusConflict:
		kind = ErrRejected
	case nativeclient.StatusDenied:
		kind = ErrAccessDenied
	case nativeclient.StatusUncertain:
		kind = ErrUnknownOutcome
	case nativeclient.StatusUnavailable, nativeclient.StatusInvalidResponse:
		kind = ErrReadFailed
	case nativeclient.StatusBusy:
		kind = ErrBusy
	case nativeclient.StatusIncompatibleVersion:
		kind = ErrIncompatibleNative
	}
	e := failure(kind, phase)
	e.NativeStatus = new(uint32)
	*e.NativeStatus = result.Status
	var body struct {
		ProtocolError string          `json:"protocol_error"`
		Err           string          `json:"err"`
		Diagnostic    json.RawMessage `json:"diagnostic"`
	}
	if len(result.Data) > 0 && json.Unmarshal(result.Data, &body) != nil {
		e.DiagnosticInvalid = true
		return e
	}
	code := body.ProtocolError
	if code == "" {
		code = body.Err
	}
	if len(code) <= 256 {
		e.Code = code
	}
	if kind != ErrUnknownOutcome {
		switch e.Code {
		case "ProcessExpired", "ProcessTerminated":
			e.Kind = ErrProcessRetired
		case "HistoryReclaimed", "QueryExpired":
			e.Kind = ErrHistoryUnavailable
		case "StaleActivation":
			e.Kind = ErrStaleOwnership
		}
	}
	if len(body.Diagnostic) != 0 && string(body.Diagnostic) != "null" {
		if len(body.Diagnostic) <= 32768 && result.DiagnosticValid {
			e.diagnostic = body.Diagnostic
		} else {
			e.DiagnosticInvalid = true
		}
	}
	return e
}
