// Transit CLI extension v1 for the pinned upstream Substrate client.
// Uses the existing UpdateActor API; no server or storage changes.
package cmd

import (
	"context"
	"fmt"

	"github.com/agent-substrate/substrate/cmd/kubectl-ate/internal/printer"
	"github.com/agent-substrate/substrate/internal/ateclient"
	"github.com/agent-substrate/substrate/pkg/proto/ateapipb"
	"github.com/spf13/cobra"
	"google.golang.org/grpc"
	"google.golang.org/protobuf/proto"
)

type transitActorClient interface {
	GetActor(context.Context, *ateapipb.GetActorRequest, ...grpc.CallOption) (*ateapipb.Actor, error)
	UpdateActor(context.Context, *ateapipb.UpdateActorRequest, ...grpc.CallOption) (*ateapipb.Actor, error)
}

func transitUpdateActor(ctx context.Context, client transitActorClient, ref *ateapipb.ObjectRef, uid, oldTemplate, targetTemplate string) (*ateapipb.Actor, error) {
	actor, err := client.GetActor(ctx, &ateapipb.GetActorRequest{Actor: ref})
	if err != nil {
		return nil, err
	}
	if uid == "" || actor.GetMetadata().GetUid() != uid || actor.GetMetadata().GetVersion() == 0 {
		return nil, fmt.Errorf("actor identity/version mismatch")
	}
	if actor.GetStatus().GetState() != ateapipb.ActorState_ACTOR_STATE_SUSPENDED {
		return nil, fmt.Errorf("actor must be suspended")
	}
	current := actor.GetActorTemplate()
	if current.GetAtespace() != ref.GetAtespace() {
		return nil, fmt.Errorf("template scope mismatch")
	}
	// A lost response is reconciled by readback, never by changing identity.
	if current.GetName() == targetTemplate {
		return actor, nil
	}
	if current.GetName() != oldTemplate || oldTemplate == "" || targetTemplate == "" {
		return nil, fmt.Errorf("template precondition mismatch")
	}
	updated := proto.CloneOf(actor)
	updated.ActorTemplate = &ateapipb.ObjectRef{Atespace: ref.GetAtespace(), Name: targetTemplate}
	// Preserve all client-settable fields. UID/version from Get guard the
	// replacement atomically at the server; do not retry an Aborted response.
	return client.UpdateActor(ctx, &ateapipb.UpdateActorRequest{Actor: updated})
}

func init() {
	var atespace, uid, previous, target string
	command := &cobra.Command{
		Use: "actor <name>", Short: "Switch a suspended Actor template with UID/version preconditions (Transit extension v1)",
		Args: cobra.ExactArgs(1),
		RunE: func(cmd *cobra.Command, args []string) error {
			client, err := ateclient.NewClient(cmd.Context(), kubeconfig, k8sContext, endpoint, tokenFile, traceEnabled)
			if err != nil {
				return err
			}
			defer client.Close()
			actor, err := transitUpdateActor(cmd.Context(), client, &ateapipb.ObjectRef{Atespace: atespace, Name: args[0]}, uid, previous, target)
			if err != nil {
				return err
			}
			return printer.PrintActorTo(cmd.OutOrStdout(), actor, outputFmt)
		},
	}
	command.Flags().StringVarP(&atespace, "atespace", "a", "", "Actor and template scope")
	command.Flags().StringVar(&uid, "expected-uid", "", "Required Actor UID")
	command.Flags().StringVar(&previous, "expected-template", "", "Required previous template name")
	command.Flags().StringVar(&target, "template", "", "Target template name in the same atespace")
	for _, flag := range []string{"atespace", "expected-uid", "expected-template", "template"} {
		_ = command.MarkFlagRequired(flag)
	}
	updateCmd.AddCommand(command)
}
