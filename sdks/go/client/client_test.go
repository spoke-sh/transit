package client

import (
	"bytes"
	"context"
	"errors"
	"fmt"
	"io"
	"os"
	"path/filepath"
	"strings"
	"testing"
	"time"

	"github.com/spoke-sh/transit/sdks/go/internal/nativeclient"
)

func openTest(t *testing.T) *Client {
	t.Helper()
	directory := os.Getenv("TRANSIT_GO_TEST_NATIVE_DIRECTORY")
	if directory == "" {
		t.Fatal("run just bindings::go-check with the built native library")
	}
	c, err := Open(Config{URL: "http://127.0.0.1:1", NativeDirectory: directory, Timeout: time.Second})
	if err != nil {
		t.Fatal(err)
	}
	t.Cleanup(func() { c.Close() })
	return c
}
func credentialTest(t *testing.T) Credential {
	t.Helper()
	path := filepath.Join(t.TempDir(), "private-seed")
	if err := os.WriteFile(path, []byte(strings.Repeat("01", 32)), 0600); err != nil {
		t.Fatal(err)
	}
	credential, err := NewCredential(72, 65536, path)
	if err != nil {
		t.Fatal(err)
	}
	return credential
}
func TestNativeWorkerRecoveryAndOwnedValues(t *testing.T) {
	c := openTest(t)
	if c.state.native.StackSize() < nativeclient.MinimumStackBytes {
		t.Fatal("native stack below ABI requirement")
	}
	credential := credentialTest(t)
	pending, err := c.PrepareSend(context.Background(), ProcessRef{72, 1}, []byte("private-payload"), credential, 1)
	if err != nil {
		t.Fatal(err)
	}
	saved := pending.Export()
	copy := pending.Export()
	clear(copy)
	if string(saved) != string(pending.Export()) {
		t.Fatal("export aliases pending storage")
	}
	recovered, err := c.RecoverSend(context.Background(), saved)
	if err != nil || recovered.Info() != pending.Info() {
		t.Fatalf("recovery: %v", err)
	}
	mutation, err := c.RecoverMutation(context.Background(), saved)
	if err != nil || mutation.Info() != pending.Info().Mutation {
		t.Fatalf("mutation recovery: %v", err)
	}
	for _, broken := range [][]byte{append([]byte(" "), saved...), []byte(`{}`), nil} {
		if _, err := c.RecoverSend(context.Background(), broken); err == nil {
			t.Fatal("accepted noncanonical envelope")
		}
	}
	// Preserve every other canonical byte so these failures isolate definition
	// rejection rather than a host JSON encoder's changed field ordering.
	marker := []byte(fmt.Sprintf("\"definition\":%q,", nativeclient.Definition))
	if !bytes.Contains(saved, marker) {
		t.Fatal("saved definition missing")
	}
	broken := bytes.Replace(saved, marker, nil, 1)
	if _, err := c.RecoverSend(context.Background(), broken); err == nil {
		t.Fatal("accepted missing definition")
	}
	broken = bytes.Replace(saved, []byte(nativeclient.Definition), []byte(strings.Repeat("0", 64)), 1)
	if _, err := c.RecoverSend(context.Background(), broken); err == nil {
		t.Fatal("accepted foreign definition")
	}
	if _, err := c.PrepareSend(context.Background(), ProcessRef{72, 1}, nil, credential, Sequence(MaxCounter+1)); err == nil {
		t.Fatal("accepted out-of-range sequence")
	}
	if _, err := c.PrepareSend(context.Background(), ProcessRef{73, 1}, nil, credential, 1); err == nil {
		t.Fatal("accepted cross-realm send")
	}
	if _, err := c.PrepareSend(context.Background(), ProcessRef{72, 1}, make([]byte, MaxValueBytes+1), credential, 1); err == nil {
		t.Fatal("accepted oversized payload")
	}
	for _, verb := range []string{"%v", "%+v", "%#v"} {
		text := fmt.Sprintf(verb, pending) + fmt.Sprintf(verb, credential)
		if strings.Contains(text, "private-") || strings.Contains(text, strings.Repeat("01", 32)) {
			t.Fatal("formatter discloses private material")
		}
	}
	canceled, cancel := context.WithCancel(context.Background())
	cancel()
	if _, err := c.Dispatch(canceled, pending); !errors.Is(err, context.Canceled) || errors.Is(err, ErrUnknownOutcome) {
		t.Fatal("preflight cancellation", err)
	}
	c.Close()
	c.Close()
	if _, err := c.RecoverSend(context.Background(), saved); !errors.Is(err, ErrClosed) {
		t.Fatal("closed owner", err)
	}
}
func TestDiagnosticDoesNotReplaceUncertainty(t *testing.T) {
	e := nativeError(nativeclient.Result{Status: nativeclient.StatusUncertain, Data: []byte(`{"err":"ProcessExpired","diagnostic":{"private":"payload"}}`)}, "dispatch")
	if !errors.Is(e, ErrUnknownOutcome) || !e.DiagnosticInvalid || e.Diagnostic() != nil {
		t.Fatal("malformed detail changed outcome")
	}
	for _, verb := range []string{"%v", "%+v", "%#v"} {
		if strings.Contains(fmt.Sprintf(verb, e), "payload") {
			t.Fatal("diagnostic disclosure")
		}
	}
}
func TestBusyCancellationAndJoinedClose(t *testing.T) {
	c := openTest(t)
	entered, release := make(chan struct{}), make(chan struct{})
	ctx, cancel := context.WithCancel(context.Background())
	result := make(chan error, 1)
	go func() {
		_, err := run(ctx, c, "test", []byte("original"), func(*owner) (int, error) { close(entered); <-release; return 1, nil })
		result <- err
	}()
	<-entered
	cancel()
	if err := <-result; !errors.Is(err, context.Canceled) || !errors.Is(err, ErrUnknownOutcome) {
		t.Fatal(err)
	}
	if _, err := run(context.Background(), c, "overlap", nil, func(*owner) (int, error) { t.Error("overlapping work admitted"); return 0, nil }); !errors.Is(err, ErrBusy) {
		t.Fatal(err)
	}
	closed := make(chan struct{})
	go func() { c.Close(); close(closed) }()
	select {
	case <-closed:
		t.Fatal("closed while work owned")
	case <-time.After(20 * time.Millisecond):
	}
	close(release)
	select {
	case <-closed:
	case <-time.After(time.Second):
		t.Fatal("close did not join")
	}
}

func TestNativeImageReplacementRejects(t *testing.T) {
	directory := os.Getenv("TRANSIT_GO_TEST_NATIVE_DIRECTORY")
	if directory == "" {
		t.Fatal("run just bindings::go-check")
	}
	installed := t.TempDir()
	path := filepath.Join(installed, "libtransit_client.so")
	copyLibrary := func(destination string) {
		source, err := os.Open(filepath.Join(directory, "libtransit_client.so"))
		if err != nil {
			t.Fatal(err)
		}
		defer source.Close()
		output, err := os.Create(destination)
		if err != nil {
			t.Fatal(err)
		}
		_, err = io.Copy(output, source)
		closeErr := output.Close()
		if err != nil {
			t.Fatal(err)
		}
		if closeErr != nil {
			t.Fatal(closeErr)
		}
	}
	copyLibrary(path)
	config := Config{URL: "http://127.0.0.1:1", NativeDirectory: installed}
	c, err := Open(config)
	if err != nil {
		t.Fatal(err)
	}
	c.Close()
	// Replace the directory entry, never truncate an actively mapped image.
	replacement := filepath.Join(installed, "replacement.so")
	copyLibrary(replacement)
	if err := os.Rename(replacement, path); err != nil {
		t.Fatal(err)
	}
	if c, err := Open(config); !errors.Is(err, ErrIncompatibleNative) {
		if c != nil {
			c.Close()
		}
		t.Fatal("replacement admitted", err)
	}
	if err := os.Remove(path); err != nil {
		t.Fatal(err)
	}
	if c, err := Open(config); !errors.Is(err, ErrIncompatibleNative) {
		if c != nil {
			c.Close()
		}
		t.Fatal("missing override admitted", err)
	}
}
