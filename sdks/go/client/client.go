package client

import (
	"bytes"
	"context"
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"errors"
	"io"
	"net/url"
	"os"
	"path/filepath"
	"strconv"
	"strings"
	"sync"
	"time"

	"github.com/spoke-sh/transit/sdks/go/internal/nativeclient"
)

// Client is safe to call from multiple goroutines, but admits one active
// operation. Overlap returns ErrBusy. Copies share the same owner and Close.
// Separate handles sharing a principal still require coordinated sequences.
type Client struct{ state *owner }
type owner struct {
	mu            sync.Mutex
	native        *nativeclient.Client
	active        chan struct{}
	closing       bool
	closed        chan struct{}
	lastAdmission *AdmissionReceipt
	lastMutation  *MutationReceipt
}

func Open(config Config) (*Client, error) {
	address, err := url.Parse(config.URL)
	if err != nil || address.Host == "" || (address.Scheme != "http" && address.Scheme != "https") ||
		address.User != nil || address.RawQuery != "" || address.Fragment != "" || len(config.URL) > 2048 ||
		strings.ContainsRune(config.URL, 0) || config.NativeDirectory == "" || strings.ContainsRune(config.NativeDirectory, 0) {
		return nil, failure(ErrInvalidArgument, "configuration")
	}
	timeout := config.Timeout
	if timeout == 0 {
		timeout = 30 * time.Second
	}
	if timeout < time.Millisecond || timeout > time.Minute || timeout%time.Millisecond != 0 {
		return nil, failure(ErrInvalidArgument, "timeout")
	}
	directory, err := filepath.Abs(config.NativeDirectory)
	if err != nil {
		return nil, failure(ErrInvalidArgument, "native-directory")
	}
	native, status := nativeclient.Open(filepath.Join(directory, "libtransit_client.so"), config.URL, uint32(timeout/time.Millisecond))
	if status != 0 {
		return nil, nativeError(nativeclient.Result{Status: status}, "open")
	}
	return &Client{state: &owner{native: native, closed: make(chan struct{})}}, nil
}

type completion[T any] struct {
	value T
	err   error
}

func run[T any](ctx context.Context, client *Client, phase string, recovery []byte, work func(*owner) (T, error)) (T, error) {
	var zero T
	if ctx == nil {
		return zero, failure(ErrInvalidArgument, phase)
	}
	if err := ctx.Err(); err != nil {
		return zero, err
	}
	if client == nil || client.state == nil {
		return zero, failure(ErrClosed, phase)
	}
	state := client.state
	state.mu.Lock()
	if state.closing {
		state.mu.Unlock()
		return zero, failure(ErrClosed, phase)
	}
	if state.active != nil {
		state.mu.Unlock()
		return zero, failure(ErrBusy, phase)
	}
	done := make(chan struct{})
	state.active = done
	state.mu.Unlock()
	result := make(chan completion[T], 1)
	// At most one admitted goroutine per handle. Cancellation abandons only the
	// receive; this owner keeps all native inputs alive and retains the receipt.
	go func() {
		value, err := work(state)
		state.mu.Lock()
		state.active = nil
		result <- completion[T]{value, err}
		close(done)
		state.mu.Unlock()
	}()
	select {
	case result := <-result:
		return result.value, result.err
	case <-ctx.Done():
		// Prefer an already observed outcome over a simultaneous cancellation.
		select {
		case result := <-result:
			return result.value, result.err
		default:
		}
		if recovery != nil {
			err := failure(ErrUnknownOutcome, phase)
			err.cause = ctx.Err()
			return zero, &DispatchError{Cause: err, recovery: append([]byte(nil), recovery...)}
		}
		return zero, ctx.Err()
	}
}

// Close stops admission, waits for active native work, and releases the worker.
// It is idempotent, supports concurrent callers, and implements io.Closer.
// It does not cancel or roll back accepted work. Receipts remain inspectable.
func (c *Client) Close() error {
	if c == nil || c.state == nil {
		return nil
	}
	state := c.state
	state.mu.Lock()
	if state.closing {
		done := state.closed
		state.mu.Unlock()
		<-done
		return nil
	}
	state.closing = true
	active := state.active
	state.mu.Unlock()
	if active != nil {
		<-active
	}
	state.native.Close()
	close(state.closed)
	return nil
}
func (c *Client) LastAdmission() (AdmissionReceipt, bool) {
	if c == nil || c.state == nil {
		return AdmissionReceipt{}, false
	}
	c.state.mu.Lock()
	defer c.state.mu.Unlock()
	if c.state.lastAdmission == nil {
		return AdmissionReceipt{}, false
	}
	return *c.state.lastAdmission, true
}
func (c *Client) LastMutation() (MutationReceipt, bool) {
	if c == nil || c.state == nil {
		return MutationReceipt{}, false
	}
	c.state.mu.Lock()
	defer c.state.mu.Unlock()
	if c.state.lastMutation == nil {
		return MutationReceipt{}, false
	}
	return *c.state.lastMutation, true
}

func readSeed(credential Credential) ([]byte, error) {
	if !positive(credential.realm) || credential.principal > MaxCounter || credential.seedFile == "" {
		return nil, failure(ErrInvalidArgument, "credential")
	}
	file, err := os.Open(credential.seedFile)
	if err != nil {
		return nil, failure(ErrInvalidArgument, "credential")
	}
	defer file.Close()
	raw, err := io.ReadAll(io.LimitReader(file, 129))
	defer clear(raw)
	if err != nil || len(raw) > 128 {
		return nil, failure(ErrInvalidArgument, "credential")
	}
	text := bytes.TrimSpace(raw)
	if len(text) != 64 {
		return nil, failure(ErrInvalidArgument, "credential")
	}
	seed := make([]byte, 32)
	if _, err := hex.Decode(seed, text); err != nil {
		clear(seed)
		return nil, failure(ErrInvalidArgument, "credential")
	}
	return seed, nil
}

func (c *Client) Capabilities(ctx context.Context, credential Credential) (Capabilities, error) {
	return run(ctx, c, "capabilities", nil, func(state *owner) (Capabilities, error) {
		seed, err := readSeed(credential)
		if err != nil {
			return Capabilities{}, err
		}
		defer clear(seed)
		data, _ := json.Marshal(map[string]any{"realm": credential.realm, "principal": credential.principal, "kind": map[string]any{"capabilities": struct{}{}}})
		result := state.native.Query(seed, data)
		if result.Status != 0 {
			return Capabilities{}, nativeError(result, "capabilities")
		}
		return decodeCapabilities(result.Data, credential.realm)
	})
}
func (c *Client) PrepareSend(ctx context.Context, peer ProcessRef, value []byte, credential Credential, sequence Sequence) (*PendingSend, error) {
	if !positive(peer.Realm) || !positive(peer.PID) || peer.Realm != credential.realm ||
		!positive(uint64(sequence)) || len(value) > MaxValueBytes {
		return nil, failure(ErrInvalidArgument, "prepare-send")
	}
	// Build the owned request before asynchronous admission; the caller may
	// immediately reuse its original payload after this method returns.
	data, _ := json.Marshal(map[string]any{"realm": credential.realm, "principal": credential.principal, "sequence": uint64(sequence),
		"command": map[string]any{"send": map[string]any{"pid": peer.PID, "value": hex.EncodeToString(value)}}})
	return run(ctx, c, "prepare-send", nil, func(state *owner) (*PendingSend, error) {
		seed, err := readSeed(credential)
		if err != nil {
			return nil, err
		}
		defer clear(seed)
		result := state.native.Prepare(seed, data)
		if result.Status != 0 {
			return nil, nativeError(result, "prepare-send")
		}
		return decodeSend(result)
	})
}
func boundedSaved(data []byte) ([]byte, error) {
	if len(data) == 0 || len(data) > nativeclient.MaxBody {
		return nil, failure(ErrInvalidArgument, "saved-operation")
	}
	return append([]byte(nil), data...), nil
}

// RecoverSend imports the original native envelope without a signing seed.
// It verifies canonical shape and classifies the operation in Zig. Authority
// signature and current-grant checks still occur on dispatch.
func (c *Client) RecoverSend(ctx context.Context, saved []byte) (*PendingSend, error) {
	data, err := boundedSaved(saved)
	if err != nil {
		return nil, err
	}
	return run(ctx, c, "recover-send", nil, func(state *owner) (*PendingSend, error) {
		result := state.native.Inspect(data)
		if result.Status != 0 {
			return nil, nativeError(result, "recover-send")
		}
		return decodeSend(result)
	})
}
func (c *Client) RecoverMutation(ctx context.Context, saved []byte) (*PendingMutation, error) {
	data, err := boundedSaved(saved)
	if err != nil {
		return nil, err
	}
	return run(ctx, c, "recover-mutation", nil, func(state *owner) (*PendingMutation, error) {
		result := state.native.Inspect(data)
		if result.Status != 0 {
			return nil, nativeError(result, "recover-mutation")
		}
		info, _, err := decodeInfo(result.Metadata, result.Data)
		if err != nil {
			return nil, err
		}
		return &PendingMutation{info: info, bytes: result.Data}, nil
	})
}
func dispatch(state *owner, data []byte) (uint64, error) {
	result := state.native.Call(data)
	if result.Status != 0 {
		err := nativeError(result, "dispatch")
		if errors.Is(err, ErrUnknownOutcome) {
			return 0, &DispatchError{Cause: err, recovery: append([]byte(nil), data...)}
		}
		return 0, &DispatchError{Cause: err}
	}
	var receipt struct {
		Position uint64 `json:"position"`
	}
	if json.Unmarshal(result.Data, &receipt) != nil || !positive(receipt.Position) {
		return 0, &DispatchError{Cause: failure(ErrUnknownOutcome, "receipt"), recovery: append([]byte(nil), data...)}
	}
	return receipt.Position, nil
}
func (c *Client) Dispatch(ctx context.Context, pending *PendingSend) (AdmissionReceipt, error) {
	if pending == nil || len(pending.bytes) == 0 {
		return AdmissionReceipt{}, failure(ErrInvalidArgument, "dispatch")
	}
	return run(ctx, c, "dispatch", pending.bytes, func(state *owner) (AdmissionReceipt, error) {
		position, err := dispatch(state, pending.bytes)
		receipt := AdmissionReceipt{Position: position, Identity: pending.info.Mutation.Identity}
		if err == nil {
			state.mu.Lock()
			state.lastAdmission = &receipt
			state.mu.Unlock()
		}
		return receipt, err
	})
}
func (c *Client) DispatchMutation(ctx context.Context, pending *PendingMutation) (MutationReceipt, error) {
	if pending == nil || len(pending.bytes) == 0 {
		return MutationReceipt{}, failure(ErrInvalidArgument, "dispatch")
	}
	return run(ctx, c, "dispatch", pending.bytes, func(state *owner) (MutationReceipt, error) {
		position, err := dispatch(state, pending.bytes)
		receipt := MutationReceipt{Position: position, Identity: pending.info.Identity}
		if err == nil {
			state.mu.Lock()
			state.lastMutation = &receipt
			state.mu.Unlock()
		}
		return receipt, err
	})
}

func decodeInfo(data, saved []byte) (MutationInfo, uint64, error) {
	var wire struct {
		Version     uint64  `json:"version"`
		Profile     string  `json:"profile"`
		Kind        string  `json:"kind"`
		Identity    string  `json:"identity"`
		Realm       uint64  `json:"realm"`
		Principal   *uint64 `json:"principal"`
		Sequence    string  `json:"sequence"`
		Command     string  `json:"command"`
		Destination *uint64 `json:"destination"`
	}
	invalid := failure(ErrIncompatibleNative, "metadata")
	if json.Unmarshal(data, &wire) != nil {
		return MutationInfo{}, 0, invalid
	}
	if wire.Version != 1 || wire.Profile != "native_v1" || wire.Kind != "growing_command" {
		return MutationInfo{}, 0, failure(ErrUnsupportedCapability, "metadata")
	}
	sequence, err := strconv.ParseUint(wire.Sequence, 10, 64)
	identity := sha256.Sum256(saved)
	if err != nil || strconv.FormatUint(sequence, 10) != wire.Sequence || !positive(sequence) ||
		!positive(wire.Realm) || wire.Principal == nil || *wire.Principal > MaxCounter ||
		len(wire.Command) == 0 || len(wire.Command) > 64 || wire.Identity != hex.EncodeToString(identity[:]) {
		return MutationInfo{}, 0, invalid
	}
	destination := uint64(0)
	if wire.Destination != nil {
		destination = *wire.Destination
	}
	return MutationInfo{wire.Identity, wire.Realm, *wire.Principal, Sequence(sequence), wire.Command}, destination, nil
}
func decodeSend(result nativeclient.Result) (*PendingSend, error) {
	info, destination, err := decodeInfo(result.Metadata, result.Data)
	if err != nil {
		return nil, err
	}
	if info.Command != "send" {
		return nil, failure(ErrUnsupportedCapability, "send-metadata")
	}
	if !positive(destination) {
		return nil, failure(ErrIncompatibleNative, "send-metadata")
	}
	return &PendingSend{SendInfo{info, ProcessRef{info.Realm, destination}}, result.Data}, nil
}

func decodeCapabilities(data []byte, realm uint64) (Capabilities, error) {
	var wire struct {
		Version           uint64  `json:"version"`
		Realm             uint64  `json:"realm"`
		Position          *uint64 `json:"position"`
		PrincipalSequence *uint64 `json:"principal_sequence"`
		Body              struct {
			Capabilities struct {
				Version              uint64 `json:"version"`
				Profile              string `json:"profile"`
				PageEntries          uint64 `json:"page_entries"`
				MutationBudget       uint64 `json:"mutation_budget"`
				OutputBudget         uint64 `json:"output_budget"`
				RetainedReadVersions *bool  `json:"retained_read_versions"`
				AssociationLookup    *bool  `json:"association_lookup"`
				ScopedRetry          *bool  `json:"scoped_retry"`
				Station              *bool  `json:"station"`
			} `json:"capabilities"`
		} `json:"body"`
	}
	if json.Unmarshal(data, &wire) != nil {
		return Capabilities{}, failure(ErrReadFailed, "capabilities-response")
	}
	caps := wire.Body.Capabilities
	if wire.Version != 1 || caps.Version != 1 || caps.Profile != "growing_v1" {
		return Capabilities{}, failure(ErrUnsupportedCapability, "authority-capabilities")
	}
	if wire.Realm != realm || wire.Position == nil || *wire.Position > MaxCounter || wire.PrincipalSequence == nil || *wire.PrincipalSequence > MaxCounter ||
		!positive(caps.PageEntries) || !positive(caps.MutationBudget) || !positive(caps.OutputBudget) ||
		caps.RetainedReadVersions == nil || caps.AssociationLookup == nil || caps.ScopedRetry == nil || caps.Station == nil {
		return Capabilities{}, failure(ErrReadFailed, "capabilities-response")
	}
	return Capabilities{wire.Realm, *wire.Position, *wire.PrincipalSequence, caps.PageEntries, caps.MutationBudget, caps.OutputBudget,
		*caps.RetainedReadVersions, *caps.AssociationLookup, *caps.ScopedRetry, *caps.Station}, nil
}
