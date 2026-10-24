//go:build !linux || !amd64 || !cgo

package nativeclient

// Unsupported platforms retain value APIs, but native operations fail before
// handle creation. There is no alternate protocol or transport fallback.
type Client struct{}
type Result struct {
	Status          uint32
	Data, Metadata  []byte
	DiagnosticValid bool
}

func Open(string, string, uint32) (*Client, uint32) { return nil, StatusIncompatibleVersion }
func (*Client) Prepare([]byte, []byte) Result       { return Result{Status: StatusIncompatibleVersion} }
func (*Client) Inspect([]byte) Result               { return Result{Status: StatusIncompatibleVersion} }
func (*Client) Call([]byte) Result                  { return Result{Status: StatusIncompatibleVersion} }
func (*Client) Query([]byte, []byte) Result         { return Result{Status: StatusIncompatibleVersion} }
func (*Client) Close()                              {}
func (*Client) StackSize() uint64                   { return 0 }
