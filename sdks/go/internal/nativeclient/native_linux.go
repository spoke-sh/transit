//go:build linux && (amd64 || arm64) && cgo

// Package nativeclient is the private, synchronous generated-ABI adapter.
// Its owner must serialize calls and join them before Close.
package nativeclient

/*
#cgo CFLAGS: -std=c11 -Wall -Wextra -Werror
#cgo LDFLAGS: -ldl -lpthread
#include <stdlib.h>
#include <string.h>
#include "bridge.h"
*/
import "C"

import "unsafe"

type Client struct{ worker *C.transit_go_worker }
type Result struct {
	Status          uint32
	Data, Metadata  []byte
	DiagnosticValid bool
}

func Open(path, url string, timeout uint32) (*Client, uint32) {
	name := C.CString(path)
	address := C.CBytes([]byte(url))
	defer C.free(unsafe.Pointer(name))
	defer C.free(address)
	var worker *C.transit_go_worker
	status := C.transit_go_open(name, (*C.uint8_t)(address), C.size_t(len(url)), C.uint32_t(timeout), &worker)
	if status != 0 {
		return nil, uint32(status)
	}
	return &Client{worker: worker}, 0
}

func (c *Client) execute(action, kind uint32, seed, data []byte) Result {
	// Native workers only receive C allocations. No Go pointer survives a cgo
	// call or is retained by Zig. The caller owns these until the worker joins.
	input := C.CBytes(data)
	defer C.free(input)
	var key unsafe.Pointer
	if seed != nil {
		key = C.CBytes(seed)
		defer func() { C.memset(key, 0, C.size_t(len(seed))); C.free(key) }()
	}
	output := C.transit_go_call(c.worker, C.uint32_t(action), C.uint32_t(kind), (*C.uint8_t)(key), (*C.uint8_t)(input), C.size_t(len(data)))
	defer C.transit_go_result_release(&output)
	return Result{uint32(output.status), C.GoBytes(unsafe.Pointer(output.data), C.int(output.size)),
		C.GoBytes(unsafe.Pointer(output.metadata), C.int(output.metadata_size)), output.diagnostic_valid == 1}
}
func (c *Client) Prepare(seed, data []byte) Result {
	return c.execute(C.TRANSIT_GO_PREPARE, KindGrowingCommand, seed, data)
}
func (c *Client) Inspect(data []byte) Result { return c.execute(C.TRANSIT_GO_INSPECT, 0, nil, data) }
func (c *Client) Call(data []byte) Result    { return c.execute(C.TRANSIT_GO_CALL, 0, nil, data) }
func (c *Client) Query(seed, data []byte) Result {
	return c.execute(C.TRANSIT_GO_QUERY, KindGrowingQuery, seed, data)
}
func (c *Client) Close()            { C.transit_go_close(c.worker); c.worker = nil }
func (c *Client) StackSize() uint64 { return uint64(C.transit_go_stack_size(c.worker)) }
