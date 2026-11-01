//go:build serving_native

package serving

import (
	"bytes"
	"context"
	"encoding/json"
	"encoding/pem"
	"errors"
	"net/http"
	"net/http/httptest"
	"os"
	"path/filepath"
	"sync"
	"testing"
	"time"
)

// This installed-caller fixture qualifies transport/recovery, not a Serving
// authority. Platform's independent consumer exercises the real authority.
func TestInstalledNativeCaller(t *testing.T) {
	executable := os.Getenv("TRANSIT_SERVING_CLIENT")
	if !filepath.IsAbs(executable) {
		t.Fatal("TRANSIT_SERVING_CLIENT must select an installed caller")
	}
	root := t.TempDir()
	seed := filepath.Join(root, "seed")
	ca := filepath.Join(root, "ca.pem")
	if err := os.WriteFile(seed, bytes.Repeat([]byte("07"), 32), 0600); err != nil {
		t.Fatal(err)
	}
	var mu sync.Mutex
	var bodies [][]byte
	server := httptest.NewTLSServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.Header.Get("Authorization") != "" {
			t.Error("unexpected ambient credentials")
		}
		var body json.RawMessage
		if json.NewDecoder(http.MaxBytesReader(w, r.Body, 64*1024)).Decode(&body) != nil {
			w.WriteHeader(400)
			return
		}
		if r.URL.Path == "/slow" {
			select {
			case <-r.Context().Done():
				return
			case <-time.After(2 * time.Second):
			}
		}
		w.Header().Set("Content-Type", "application/json")
		if r.URL.Path == "/serving/v1/command" {
			mu.Lock()
			bodies = append(bodies, bytes.Clone(body))
			mu.Unlock()
			w.WriteHeader(202)
			_, _ = w.Write([]byte(`{"stage":"ingress_accepted","receipt":{"position":7}}`))
			return
		}
		if r.URL.Path == "/missing" {
			w.WriteHeader(404)
			_, _ = w.Write([]byte(`{"error":"ApplicationNotFound"}`))
			return
		}
		_, _ = w.Write([]byte(`{"observed":true}`))
	}))
	defer server.Close()
	if err := os.WriteFile(ca, pem.EncodeToMemory(&pem.Block{Type: "CERTIFICATE", Bytes: server.Certificate().Raw}), 0600); err != nil {
		t.Fatal(err)
	}
	config := Config{Executable: executable, Origin: server.URL, Realm: 49, Principal: 65536, CredentialEpoch: 1, Ingress: 3, Service: 1, SeedFile: seed, CAFile: &ca, TimeoutMS: 1000}
	client, err := Open(config)
	if err != nil {
		t.Fatal(err)
	}
	defer client.Close()
	ctx := context.Background()
	pending, err := client.Prepare(ctx, 3, Submit{Operation: 8, Binding: 1, Codec: 2, DeadlineMS: 9007199254740000, Payload: []byte("hello")})
	if err != nil {
		t.Fatal(err)
	}
	if bytes.Contains(pending.Export(), bytes.Repeat([]byte("07"), 32)) {
		t.Fatal("seed disclosed")
	}
	recovered, metadata, err := client.Recover(ctx, pending.Export())
	if err != nil || metadata.Sequence != 3 || metadata.Command.Operation != 8 {
		t.Fatalf("recover: %v", err)
	}
	if !bytes.Equal(recovered.Export(), pending.Export()) {
		t.Fatal("recovery changed exact identity")
	}
	for _, p := range []*Pending{pending, recovered} {
		r, e := client.Dispatch(ctx, p)
		if e != nil || r.HTTPStatus != 202 {
			t.Fatalf("dispatch: %v status %d", e, r.HTTPStatus)
		}
	}
	mu.Lock()
	if len(bodies) != 2 || !bytes.Equal(bodies[0], bodies[1]) {
		t.Error("retry changed transmitted work")
	}
	mu.Unlock()
	otherConfig := config
	otherConfig.Principal++
	other, _ := Open(otherConfig)
	defer other.Close()
	if _, _, e := other.Recover(ctx, pending.Export()); e == nil {
		t.Fatal("scope substitution admitted")
	}
	if _, _, e := client.Recover(ctx, append([]byte(" "), pending.Export()...)); e == nil {
		t.Fatal("noncanonical recovery admitted")
	}
	read, e := client.ReadApplication(ctx, "/missing", [32]byte{1}, json.RawMessage(`{"id":1}`))
	if e != nil || read.HTTPStatus != 404 {
		t.Fatalf("domain error lost: %v %d", e, read.HTTPStatus)
	}
	untrustedConfig := config
	untrustedConfig.CAFile = nil
	untrusted, _ := Open(untrustedConfig)
	defer untrusted.Close()
	if _, e := untrusted.ReadApplication(ctx, "/read", [32]byte{1}, json.RawMessage(`{}`)); e == nil {
		t.Fatal("untrusted TLS accepted")
	}
	limited, cancel := context.WithTimeout(ctx, 100*time.Millisecond)
	defer cancel()
	if _, e := client.ReadApplication(limited, "/slow", [32]byte{1}, json.RawMessage(`{}`)); !errors.Is(e, context.DeadlineExceeded) {
		t.Fatalf("cancellation did not join: %v", e)
	}
	if _, e := client.ReadApplication(ctx, "/read", [32]byte{1}, json.RawMessage(`{}`)); e != nil {
		t.Fatalf("caller stuck after cancellation: %v", e)
	}
	client.Close()
	if _, e := client.Dispatch(ctx, pending); !errors.Is(e, ErrClosed) {
		t.Fatalf("closed caller admitted work: %v", e)
	}
}
