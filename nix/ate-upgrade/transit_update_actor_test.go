package cmd

import (
	"context"
	"errors"
	"testing"

	"github.com/agent-substrate/substrate/pkg/proto/ateapipb"
	"google.golang.org/grpc"
)

type transitFakeActors struct {
	actor   *ateapipb.Actor
	updates int
	err     error
}

func (f *transitFakeActors) GetActor(context.Context, *ateapipb.GetActorRequest, ...grpc.CallOption) (*ateapipb.Actor, error) {
	return f.actor, nil
}
func (f *transitFakeActors) UpdateActor(_ context.Context, r *ateapipb.UpdateActorRequest, _ ...grpc.CallOption) (*ateapipb.Actor, error) {
	f.updates++
	if f.err != nil {
		return nil, f.err
	}
	f.actor = r.Actor
	return f.actor, nil
}
func TestTransitUpdateActor(t *testing.T) {
	ref := &ateapipb.ObjectRef{Atespace: "test", Name: "actor"}
	for _, scenario := range []string{"switch", "retry", "uid", "running", "template", "conflict"} {
		t.Run(scenario, func(t *testing.T) {
			f := &transitFakeActors{actor: &ateapipb.Actor{
				Metadata:      &ateapipb.ResourceMetadata{Uid: "uid", Version: 42, Atespace: "test", Name: "actor"},
				ActorTemplate: &ateapipb.ObjectRef{Atespace: "test", Name: "old"},
				Status:        &ateapipb.ActorStatus{State: ateapipb.ActorState_ACTOR_STATE_SUSPENDED},
			}}
			switch scenario {
			case "retry":
				f.actor.ActorTemplate.Name = "new"
			case "uid":
				f.actor.Metadata.Uid = "replacement"
			case "running":
				f.actor.Status.State = ateapipb.ActorState_ACTOR_STATE_RUNNING
			case "template":
				f.actor.ActorTemplate.Name = "unrelated"
			case "conflict":
				f.err = errors.New("concurrent update")
			}
			actor, err := transitUpdateActor(context.Background(), f, ref, "uid", "old", "new")
			if scenario == "switch" || scenario == "retry" {
				if err != nil || actor.ActorTemplate.Name != "new" || actor.Metadata.Version != 42 {
					t.Fatalf("bad switch: %v", err)
				}
			} else if err == nil {
				t.Fatal("precondition bypass")
			}
			expected := 0
			if scenario == "switch" || scenario == "conflict" {
				expected = 1
			}
			if f.updates != expected {
				t.Fatalf("updates = %d, want %d", f.updates, expected)
			}
		})
	}
}
