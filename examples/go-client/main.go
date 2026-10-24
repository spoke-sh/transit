// A raw caller with separate preparation and exact dispatch. It never assigns a
// fresh sequence while recovering an uncertain operation.
package main

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"os"
	"path/filepath"

	"github.com/spoke-sh/transit/sdks/go/client"
)

type configuration struct {
	URL             string `json:"url"`
	NativeDirectory string `json:"native_directory"`
	Realm           uint64 `json:"realm"`
	Principal       uint64 `json:"principal"`
	PID             uint64 `json:"pid"`
	Sequence        uint64 `json:"sequence"`
	Seed            string `json:"seed"`
	Pending         string `json:"pending"`
	Value           string `json:"value"`
}

func main() {
	if err := run(); err != nil {
		fmt.Fprintln(os.Stderr, err)
		os.Exit(1)
	}
}
func run() error {
	if len(os.Args) != 3 {
		return errors.New("usage: transit-go-client capabilities|prepare|dispatch CONFIG.json")
	}
	file, err := os.Open(os.Args[2])
	if err != nil {
		return errors.New("cannot open configuration")
	}
	decoder := json.NewDecoder(io.LimitReader(file, 8193))
	decoder.DisallowUnknownFields()
	var config configuration
	err = decoder.Decode(&config)
	if err == nil {
		var trailing any
		if decoder.Decode(&trailing) != io.EOF {
			err = errors.New("trailing configuration")
		}
	}
	file.Close()
	if err != nil {
		return errors.New("invalid configuration")
	}
	c, err := client.Open(client.Config{URL: config.URL, NativeDirectory: config.NativeDirectory})
	if err != nil {
		return err
	}
	defer c.Close()
	ctx := context.Background()
	switch os.Args[1] {
	case "capabilities", "prepare":
		credential, err := client.NewCredential(config.Realm, config.Principal, config.Seed)
		if err != nil {
			return err
		}
		if os.Args[1] == "capabilities" {
			capabilities, err := c.Capabilities(ctx, credential)
			if err != nil {
				return err
			}
			return json.NewEncoder(os.Stdout).Encode(capabilities)
		}
		peer, err := client.NewProcessRef(config.Realm, config.PID)
		if err != nil {
			return err
		}
		sequence, err := client.NewSequence(config.Sequence)
		if err != nil {
			return err
		}
		pending, err := c.PrepareSend(ctx, peer, []byte(config.Value), credential, sequence)
		if err != nil {
			return err
		}
		// Refuse to replace earlier recovery evidence. Sync the exact envelope
		// and its directory before reporting that it is saved. Dispatch is a
		// separate invocation, so a failed save cannot send anything.
		output, err := os.OpenFile(config.Pending, os.O_WRONLY|os.O_CREATE|os.O_EXCL, 0600)
		if err != nil {
			return errors.New("cannot create recovery file")
		}
		_, err = output.Write(pending.Export())
		if err == nil {
			err = output.Sync()
		}
		closeErr := output.Close()
		if err == nil {
			err = closeErr
		}
		if err != nil {
			return errors.New("cannot persist recovery file")
		}
		directory, err := os.Open(filepath.Dir(config.Pending))
		if err != nil {
			return errors.New("cannot open recovery directory")
		}
		err = directory.Sync()
		directory.Close()
		if err != nil {
			return errors.New("cannot sync recovery directory")
		}
		return json.NewEncoder(os.Stdout).Encode(pending.Info())
	case "dispatch":
		file, err := os.Open(config.Pending)
		if err != nil {
			return errors.New("cannot open recovery file")
		}
		saved, err := io.ReadAll(io.LimitReader(file, 262145))
		file.Close()
		if err != nil {
			return errors.New("cannot read recovery file")
		}
		pending, err := c.RecoverSend(ctx, saved)
		if err != nil {
			return err
		}
		receipt, err := c.Dispatch(ctx, pending)
		if err != nil {
			return err
		}
		return json.NewEncoder(os.Stdout).Encode(receipt)
	default:
		return errors.New("unknown operation; use capabilities, prepare or dispatch")
	}
}
