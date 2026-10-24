// Package client provides signed Transit operations and exact recovery over the
// shared Zig client. Importing it performs no I/O and discovers no credentials.
package client

import (
	"fmt"
	"io"
	"time"

	"github.com/spoke-sh/transit/sdks/go/internal/nativeclient"
)

const MaxCounter uint64 = nativeclient.MaxCounter
const MaxValueBytes = nativeclient.ValueBytes

// Config explicitly selects native v1 and the matching installed native library.
// Timeout bounds native I/O even after a caller stops waiting with its context.
// A zero Timeout selects 30 seconds. NativeDirectory is required.
type Config struct {
	URL             string
	Timeout         time.Duration
	NativeDirectory string
}

type ProcessRef struct{ Realm, PID uint64 }

func NewProcessRef(realm, pid uint64) (ProcessRef, error) {
	value := ProcessRef{realm, pid}
	if !positive(realm) || !positive(pid) {
		return ProcessRef{}, failure(ErrInvalidArgument, "process")
	}
	return value, nil
}

type ResourceRef struct{ Realm, Resource uint64 }

func NewResourceRef(realm, resource uint64) (ResourceRef, error) {
	if !positive(realm) || !positive(resource) {
		return ResourceRef{}, failure(ErrInvalidArgument, "resource")
	}
	return ResourceRef{realm, resource}, nil
}

// Sequence is application-assigned. Sharing a principal between clients requires
// a coordinated allocator; the SDK never advances a sequence automatically.
type Sequence uint64

func NewSequence(value uint64) (Sequence, error) {
	if !positive(value) {
		return 0, failure(ErrInvalidArgument, "sequence")
	}
	return Sequence(value), nil
}
func positive(value uint64) bool { return value > 0 && value <= MaxCounter }

// Credential contains a reference to an explicit signing seed, not a native key.
// Its contents are private and excluded from all fmt representations.
type Credential struct {
	realm, principal uint64
	seedFile         string
}

func NewCredential(realm, principal uint64, seedFile string) (Credential, error) {
	if !positive(realm) || principal > MaxCounter || len(seedFile) == 0 || len(seedFile) > nativeclient.MaxBody {
		return Credential{}, failure(ErrInvalidArgument, "credential")
	}
	return Credential{realm, principal, seedFile}, nil
}
func (c Credential) Realm() uint64     { return c.realm }
func (c Credential) Principal() uint64 { return c.principal }
func (c Credential) Format(state fmt.State, _ rune) {
	fmt.Fprintf(state, "Credential{realm:%d principal:%d}", c.realm, c.principal)
}

// AdmissionReceipt binds an observed position to the original frozen operation.
// It establishes input admission, independently of handler processing.
type AdmissionReceipt struct {
	Position uint64 `json:"position"`
	Identity string `json:"identity"`
}

// MutationReceipt binds native confirmation to the exact recovered mutation.
type MutationReceipt struct {
	Position uint64 `json:"position"`
	Identity string `json:"identity"`
}
type Capabilities struct {
	Realm, ObservedAt, PrincipalSequence                      uint64
	PageSize, MutationsPerTurn, OutputsPerTurn                uint64
	RetainedVersions, AssociationLookup, ScopedRetry, Station bool
}
type MutationInfo struct {
	Identity         string
	Realm, Principal uint64
	Sequence         Sequence
	Command          string
}
type SendInfo struct {
	Mutation MutationInfo
	Peer     ProcessRef
}

// PendingSend owns an immutable, canonical operation. Persist Export before
// dispatch when recovery after process loss is required. Those bytes may contain
// application data; they contain no signing seed and are not an admission receipt.
type PendingSend struct {
	info  SendInfo
	bytes []byte
}

func (p *PendingSend) Info() SendInfo {
	if p == nil {
		return SendInfo{}
	}
	return p.info
}
func (p *PendingSend) Export() []byte {
	if p == nil {
		return nil
	}
	return append([]byte(nil), p.bytes...)
}
func (p *PendingSend) Format(state fmt.State, _ rune) {
	if p == nil {
		io.WriteString(state, "PendingSend<nil>")
		return
	}
	fmt.Fprintf(state, "PendingSend{%s}", p.info.Mutation.Identity)
}

type PendingMutation struct {
	info  MutationInfo
	bytes []byte
}

func (p *PendingMutation) Info() MutationInfo {
	if p == nil {
		return MutationInfo{}
	}
	return p.info
}
func (p *PendingMutation) Export() []byte {
	if p == nil {
		return nil
	}
	return append([]byte(nil), p.bytes...)
}
func (p *PendingMutation) Format(state fmt.State, _ rune) {
	if p == nil {
		io.WriteString(state, "PendingMutation<nil>")
		return
	}
	fmt.Fprintf(state, "PendingMutation{%s}", p.info.Identity)
}
