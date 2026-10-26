package main

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"os"
	"strings"
	"time"

	"github.com/spoke-sh/transit/sdks/go/client"
)

func must[T any](value T, err error) T {
	if err != nil {
		panic(err)
	}
	return value
}
func check(ok bool, message string) {
	if !ok {
		panic(message)
	}
}
func write(path string, data []byte) {
	if err := os.WriteFile(path, data, 0600); err != nil {
		panic(err)
	}
}
func output(value any) {
	if err := json.NewEncoder(os.Stdout).Encode(value); err != nil {
		panic(err)
	}
}
func main() {
	var config struct {
		URL      string `json:"url"`
		PID      uint64 `json:"pid"`
		Seed     string `json:"seed"`
		Pending  string `json:"pending"`
		Spawn    string `json:"spawn"`
		Accepted string `json:"accepted"`
	}
	if err := json.Unmarshal(must(os.ReadFile(os.Args[2])), &config); err != nil {
		panic(err)
	}
	settings := client.Config{URL: config.URL, Timeout: 3 * time.Second, NativeDirectory: os.Getenv("TRANSIT_GO_NATIVE_DIRECTORY")}
	credential := must(client.NewCredential(72, 65536, config.Seed))
	peer := must(client.NewProcessRef(72, config.PID))
	ctx := context.Background()
	_, err := client.NewProcessRef(72, 0)
	check(err != nil, "zero pid")
	_, err = client.NewProcessRef(72, 1<<53)
	check(err != nil, "wide protocol pid")
	foreign := settings
	foreign.NativeDirectory = "/missing-transit"
	_, err = client.Open(foreign)
	check(errors.Is(err, client.ErrIncompatibleNative), "missing library")
	if os.Args[1] == "incompatible" {
		_, err = client.Open(settings)
		check(errors.Is(err, client.ErrIncompatibleNative), "incompatible native profile admitted")
		return
	}
	c := must(client.Open(settings))
	defer c.Close()
	switch os.Args[1] {
	case "first":
		caps := must(c.Capabilities(ctx, credential))
		check(caps.PrincipalSequence == 0 && caps.PageSize == 8 && caps.RetainedVersions, "capabilities")
		// Repeated handles reuse retained native code and join their I/O workers.
		for range 16 {
			probe := must(client.Open(settings))
			must(probe.Capabilities(ctx, credential))
			probe.Close()
		}
		mappings := strings.Split(string(must(os.ReadFile("/proc/self/maps"))), "\n")
		images := map[string]bool{}
		for _, line := range mappings {
			if strings.Contains(line, "libtransit_client.so") {
				fields := strings.Fields(line)
				images[fields[len(fields)-1]] = true
			}
		}
		check(len(images) == 1, "native image reuse")
		data := []byte("wide")
		pending := must(c.PrepareSend(ctx, peer, data, credential, 1))
		saved := pending.Export()
		clear(data)
		copy := pending.Export()
		clear(copy)
		check(string(saved) == string(pending.Export()), "owned recovery bytes")
		write(config.Pending, saved)
		_, err := c.Dispatch(ctx, pending)
		check(errors.Is(err, client.ErrUnknownOutcome), "lost receipt uncertainty")
		var dispatch *client.DispatchError
		check(errors.As(err, &dispatch) && string(dispatch.Recovery()) == string(saved), "exact uncertainty recovery")
		var detail *client.Error
		check(errors.As(err, &detail) && detail.NativeStatus != nil && *detail.NativeStatus == 6, "uncertain native status")
	case "recover":
		_, err := os.Stat(config.Seed)
		check(os.IsNotExist(err), "seed must be absent")
		pending := must(c.RecoverSend(ctx, must(os.ReadFile(config.Pending))))
		receipt := must(c.Dispatch(ctx, pending))
		output(receipt)
		check(must(c.Dispatch(ctx, pending)) == receipt, "duplicate exact receipt")
		_, err = c.RecoverSend(ctx, must(os.ReadFile(config.Spawn)))
		check(errors.Is(err, client.ErrUnsupportedCapability), "native send classification")
		mutation := must(c.RecoverMutation(ctx, pending.Export()))
		check(must(c.DispatchMutation(ctx, mutation)).Position == receipt.Position, "raw mutation recovery")
		_, err = c.RecoverSend(ctx, append([]byte(" "), pending.Export()...))
		check(err != nil, "noncanonical envelope")
		saved, ok := c.LastAdmission()
		check(ok && saved == receipt, "retained receipt")
	case "async":
		pending := must(c.PrepareSend(ctx, peer, []byte("async"), credential, 2))
		waiting, cancel := context.WithCancel(ctx)
		result := make(chan error, 1)
		go func() { _, err := c.Dispatch(waiting, pending); result <- err }()
		deadline := time.Now().Add(15 * time.Second)
		for {
			if _, err := os.Stat(config.Accepted); err == nil {
				break
			}
			check(time.Now().Before(deadline), "acceptance deadline")
			time.Sleep(5 * time.Millisecond)
		}
		cancel()
		err := <-result
		check(errors.Is(err, context.Canceled) && errors.Is(err, client.ErrUnknownOutcome), "cancel preserves uncertainty")
		_, err = c.Capabilities(ctx, credential)
		check(errors.Is(err, client.ErrBusy), "cancelled owner remains busy")
		closed := make(chan struct{})
		go func() { c.Close(); close(closed) }()
		beats := 0
	joining:
		for {
			select {
			case <-closed:
				break joining
			case <-time.After(10 * time.Millisecond):
				beats++
			}
		}
		check(beats > 5, "responsive joined close")
		receipt, ok := c.LastAdmission()
		check(ok, "close preserves completed receipt")
		_, err = c.Capabilities(ctx, credential)
		check(errors.Is(err, client.ErrClosed), "closed handle")
		fresh := must(client.Open(settings))
		defer fresh.Close()
		recovered := must(fresh.RecoverSend(ctx, pending.Export()))
		check(must(fresh.Dispatch(ctx, recovered)) == receipt, "cancelled accepted work exact recovery")
		output(map[string]bool{"await_cancelled": true, "overlap_rejected": true, "responsive_during_join": true, "disposed_handle_rejected": true})
	case "denied":
		pending := must(c.RecoverSend(ctx, must(os.ReadFile(config.Pending))))
		_, err := c.Dispatch(ctx, pending)
		check(errors.Is(err, client.ErrAccessDenied) && !errors.Is(err, client.ErrUnknownOutcome), "revoked retry")
	default:
		panic(fmt.Sprintf("unknown mode %q", os.Args[1]))
	}
}
