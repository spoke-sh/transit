// Package serving adapts the shared Zig Serving caller. It has no signer,
// automatic retry, sequence allocator or implicit filesystem journal.
package serving

import (
	"bytes"
	"context"
	"encoding/hex"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"os/exec"
	"path/filepath"
	"sync"
	"time"
)

var (
	ErrInvalid        = errors.New("invalid Serving request or recovery scope")
	ErrUnavailable    = errors.New("Serving observation unavailable")
	ErrUnknownOutcome = errors.New("Serving command outcome unknown; retain original work")
	ErrBusy           = errors.New("Serving caller busy")
	ErrClosed         = errors.New("Serving caller closed")
)

const MaxResponseBytes = 2 * 1024 * 1024

type Config struct {
	Executable                   string  `json:"-"`
	Origin                       string  `json:"origin"`
	Realm                        uint64  `json:"realm"`
	Principal                    uint64  `json:"principal"`
	CredentialEpoch              uint64  `json:"credential_epoch"`
	Role                         *uint64 `json:"role"`
	Ingress                      uint64  `json:"ingress"`
	Service                      uint64  `json:"service"`
	SeedFile                     string  `json:"seed_file"`
	CAFile                       *string `json:"ca_file"`
	TimeoutMS                    uint32  `json:"timeout_ms"`
	DevelopmentAllowInsecureHTTP bool    `json:"development_allow_insecure_http"`
}
type Client struct {
	mu     sync.Mutex
	config Config
	closed bool
}
type Submit struct {
	Operation  uint64 `json:"operation"`
	Binding    uint64 `json:"binding"`
	Codec      uint16 `json:"codec"`
	DeadlineMS uint64 `json:"deadline_ms"`
	Payload    []byte `json:"-"`
}
type Pending struct{ saved []byte }

func (p *Pending) Export() []byte {
	if p == nil {
		return nil
	}
	return bytes.Clone(p.saved)
}
func (Pending) String() string               { return "Serving pending operation (private recovery material)" }
func (p Pending) Format(s fmt.State, _ rune) { _, _ = io.WriteString(s, p.String()) }

type Metadata struct {
	Identity [32]byte `json:"identity"`
	Sequence uint64   `json:"sequence"`
	Command  struct {
		Operation  uint64 `json:"operation"`
		Binding    uint64 `json:"binding"`
		Codec      uint16 `json:"codec"`
		DeadlineMS uint64 `json:"deadline_ms"`
		Payload    string `json:"payload"`
	} `json:"command"`
}
type Response struct {
	HTTPStatus int
	Body       json.RawMessage
}

// Open does no network or credential I/O. Each admitted operation runs one
// bounded shared native process, joined on completion/cancellation. The process
// profile deliberately retains no accepted work: persist Pending.Export first.
func Open(config Config) (*Client, error) {
	if !filepath.IsAbs(config.Executable) || !filepath.IsAbs(config.SeedFile) || config.TimeoutMS == 0 || config.TimeoutMS > 60000 {
		return nil, ErrInvalid
	}
	for _, v := range []uint64{config.Realm, config.Principal, config.CredentialEpoch, config.Ingress, config.Service} {
		if v == 0 || v > MaxCounter {
			return nil, ErrInvalid
		}
	}
	if config.Role != nil {
		role := *config.Role
		if role > MaxCounter {
			return nil, ErrInvalid
		}
		config.Role = &role
	}
	if config.CAFile != nil {
		file := *config.CAFile
		if !filepath.IsAbs(file) {
			return nil, ErrInvalid
		}
		config.CAFile = &file
	}
	return &Client{config: config}, nil
}

// Close waits for any admitted invocation to finish, then refuses new work.
func (c *Client) Close() { c.mu.Lock(); defer c.mu.Unlock(); c.closed = true }

type boundedOutput struct {
	bytes.Buffer
	overflow bool
}

func (b *boundedOutput) Write(p []byte) (int, error) {
	if len(p) > MaxResponseBytes-b.Len() {
		b.overflow = true
		return 0, errors.New("Serving response exceeds bound")
	}
	return b.Buffer.Write(p)
}
func (c *Client) call(ctx context.Context, action any, mutation bool) (Response, error) {
	if ctx == nil {
		return Response{}, ErrInvalid
	}
	if err := ctx.Err(); err != nil {
		return Response{}, err
	}
	if !c.mu.TryLock() {
		return Response{}, ErrBusy
	}
	defer c.mu.Unlock()
	if c.closed {
		return Response{}, ErrClosed
	}
	configJSON, err := json.Marshal(c.config)
	if err != nil {
		return Response{}, ErrInvalid
	}
	var config map[string]json.RawMessage
	if json.Unmarshal(configJSON, &config) != nil {
		return Response{}, ErrInvalid
	}
	config["definition"], _ = json.Marshal(Definition)
	input, err := json.Marshal(map[string]any{"configuration": config, "action": action})
	if err != nil || len(input) >= 64*1024 {
		return Response{}, ErrInvalid
	}
	// The total host deadline also bounds startup and failed output delivery.
	limited, cancel := context.WithTimeout(ctx, time.Duration(c.config.TimeoutMS)*time.Millisecond+5*time.Second)
	defer cancel()
	cmd := exec.CommandContext(limited, c.config.Executable)
	cmd.Stdin = bytes.NewReader(append(input, '\n'))
	cmd.Stderr = io.Discard
	var output boundedOutput
	cmd.Stdout = &output
	cmd.WaitDelay = time.Second
	runErr := cmd.Run()
	if runErr != nil || output.overflow {
		if mutation {
			return Response{}, errors.Join(ErrUnknownOutcome, limited.Err())
		}
		return Response{}, errors.Join(ErrUnavailable, limited.Err())
	}
	var result struct {
		Definition string          `json:"definition"`
		Status     string          `json:"status"`
		HTTPStatus int             `json:"http_status"`
		Value      json.RawMessage `json:"value"`
		Err        *string         `json:"err"`
	}
	dec := json.NewDecoder(bytes.NewReader(output.Bytes()))
	dec.DisallowUnknownFields()
	if dec.Decode(&result) != nil || dec.Decode(new(any)) != io.EOF || result.Definition != Definition || result.Status != "ok" {
		if mutation {
			return Response{}, ErrUnknownOutcome
		}
		return Response{}, ErrUnavailable
	}
	return Response{HTTPStatus: result.HTTPStatus, Body: bytes.Clone(result.Value)}, nil
}
func (c *Client) Prepare(ctx context.Context, sequence uint64, command Submit) (*Pending, error) {
	if sequence == 0 || sequence > MaxCounter || len(command.Payload) > 64 {
		return nil, ErrInvalid
	}
	value := map[string]any{"operation": command.Operation, "binding": command.Binding, "codec": command.Codec, "deadline_ms": command.DeadlineMS, "payload": hex.EncodeToString(command.Payload)}
	response, err := c.call(ctx, map[string]any{"prepare": map[string]any{"sequence": sequence, "command": value}}, false)
	if err != nil {
		return nil, err
	}
	var saved string
	if json.Unmarshal(response.Body, &saved) != nil || len(saved) == 0 || len(saved) > 64*1024 {
		return nil, ErrInvalid
	}
	return &Pending{saved: []byte(saved)}, nil
}
func (c *Client) Recover(ctx context.Context, saved []byte) (*Pending, Metadata, error) {
	if len(saved) == 0 || len(saved) > 64*1024 {
		return nil, Metadata{}, ErrInvalid
	}
	frozen := bytes.Clone(saved)
	response, err := c.call(ctx, map[string]any{"inspect": string(frozen)}, false)
	if err != nil {
		return nil, Metadata{}, err
	}
	var metadata Metadata
	if json.Unmarshal(response.Body, &metadata) != nil || metadata.Sequence == 0 || metadata.Sequence > MaxCounter {
		return nil, Metadata{}, ErrInvalid
	}
	return &Pending{saved: frozen}, metadata, nil
}
func (c *Client) Dispatch(ctx context.Context, pending *Pending) (Response, error) {
	if pending == nil || len(pending.saved) == 0 {
		return Response{}, ErrInvalid
	}
	return c.call(ctx, map[string]any{"dispatch": string(pending.saved)}, true)
}
func (c *Client) Observe(ctx context.Context, kind string, operation uint64) (Response, error) {
	if kind != "discovery" && kind != "status" && kind != "result" && kind != "disposition" {
		return Response{}, ErrInvalid
	}
	return c.call(ctx, map[string]any{"observe": map[string]any{"kind": kind, "operation": operation}}, false)
}

// ReadApplication signs the application-owned context digest through the shared
// native subject-proof implementation. The application still validates its body.
func (c *Client) ReadApplication(ctx context.Context, path string, digest [32]byte, read json.RawMessage) (Response, error) {
	if !json.Valid(read) {
		return Response{}, ErrInvalid
	}
	return c.call(ctx, map[string]any{"application_read": map[string]any{"path": path, "context": digest, "read": read}}, false)
}
