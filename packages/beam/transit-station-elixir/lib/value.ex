defmodule Transit.Station.Sdk.Value do
  @moduledoc false
  alias Transit.Station.Sdk, as: S
  alias Transit.Client

  def result({:ok, value}), do: {:ok, convert(value)}
  def result({:error, error}), do: Client.convert({:error, error})
  def result({:error, error, evidence}), do: {:error, Client.convert(error), convert(evidence)}

  # Application state values are never traversed or rewritten by SDK conversion.
  def application({:ok, value}), do: {:ok, value}
  def application({:error, error}), do: Client.convert({:error, error})

  def native(%S.Activation{} = v),
    do: {:transit_activation, Client.native(v.process), v.generation, Client.native(v.credential)}

  def native(%S.ServiceConfig{} = v),
    do:
      {:transit_service, Client.native(v.client), native(v.activation), v.association,
       v.query_results}

  def native(%S.Key{} = v), do: {:transit_key, v.name, v.codec}
  def native(%S.ReadVersion{} = v), do: {:transit_read_version, v.pid, v.input, v.index}

  def native(%S.Incoming{} = v),
    do: {:transit_incoming, v.kind, v.value, v.position, v.origin, optional(v.correlation)}

  def optional(nil), do: :undefined
  def optional(v), do: v
  def wait(:untimed), do: :untimed
  def wait({:until, at, observer}), do: {:until, at, Client.native(observer)}

  def convert({:transit_turn, _, _, _} = v), do: %S.Turn{native: v}
  def convert({:transit_state, _, _} = v), do: %S.State{native: v}
  def convert({:transit_source, _, _} = v), do: %S.Source{native: v}
  def convert({:transit_table, _, _, _, _} = v), do: %S.Table{native: v}
  def convert({:transit_result, _, _} = v), do: %S.ResultReader{native: v}
  def convert({:transit_key, name, codec}), do: %S.Key{name: name, codec: codec}

  def convert({:transit_incoming, kind, value, position, origin, correlation}),
    do: %S.Incoming{
      kind: kind,
      value: value,
      position: position,
      origin: origin(origin),
      correlation: convert(correlation)
    }

  def convert({:transit_control, kind, position, origin, correlation}),
    do: %S.Control{
      kind: kind,
      position: position,
      origin: origin(origin),
      correlation: correlation
    }

  def convert({:transit_result_complete, position, origin, correlation}),
    do: %S.ResultComplete{position: position, origin: origin(origin), correlation: correlation}

  def convert({:transit_read_version, pid, input, index}),
    do: %S.ReadVersion{pid: pid, input: input, index: index}

  def convert({:transit_basis, resource, revision, schema}),
    do: %S.Basis{resource: Client.convert(resource), revision: revision, schema: schema}

  def convert({:transit_page, entries, cursor, basis}),
    do: %S.Page{
      entries: Enum.map(entries, &convert/1),
      cursor: convert(cursor),
      basis: convert(basis)
    }

  def convert({:transit_kv_entry, key, value, revision}),
    do: %S.KVEntry{key: key, value: value, revision: revision}

  def convert({:transit_catalog_schema, _, _, _, _, _} = v), do: S.Catalog.convert(v)

  def convert({:transit_row, identity, cells}),
    do: %S.Row{identity: identity, cells: S.Logical.convert(cells)}

  def convert({:transit_table_basis, resource, revision, object, head}),
    do: %S.TableBasis{
      resource: Client.convert(resource),
      revision: revision,
      object: object,
      head: head
    }

  def convert({:transit_table_page, rows, next}),
    do: %S.TablePage{rows: Enum.map(rows, &convert/1), next: convert(next)}

  def convert({:transit_table_creation, state, admitted, completed}),
    do: %S.TableCreation{
      state: state,
      admitted_input: admitted,
      completed_input: convert(completed)
    }

  def convert({:transit_table_mutation, _} = v), do: %S.TableMutation{native: v}
  def convert({:transit_table_reference, _} = v), do: %S.TableMutationReference{native: v}

  def convert(
        {:transit_table_status, reference, state, route, admitted, completed, counts, rejection,
         witness}
      ),
      do: %S.TableStatus{
        reference: convert(reference),
        state: state,
        route: route,
        admitted_input: admitted,
        completed_input: convert(completed),
        counts: S.Catalog.convert(counts),
        rejection: rejection,
        witness: convert(witness)
      }

  def convert({:transit_table_witness, source, row, column, text, truncated}),
    do: %S.TableWitness{
      source: source,
      row: convert(row),
      column: column,
      text: text,
      truncated: truncated
    }

  def convert({:found, value}), do: {:found, convert(value)}

  def convert({:transit_query_job, result, correlation, source}),
    do: %S.QueryJob{result: result, correlation: correlation, source: convert(source)}

  def convert(
        {:transit_manifest, result, source, destination, correlation, table, policy, basis, plan,
         segments, bytes, rows, chain, schema}
      ),
      do: %S.Manifest{
        result: result,
        source: Client.convert(source),
        destination: Client.convert(destination),
        correlation: correlation,
        table: table,
        policy_revision: policy,
        basis: convert(basis),
        plan: plan,
        segments: segments,
        byte_count: bytes,
        rows: rows,
        chain: chain,
        schema: schema
      }

  def convert({:transit_ipc_segment, manifest, ordinal, rows, digest, ipc}),
    do: %S.IpcSegment{
      manifest: convert(manifest),
      ordinal: ordinal,
      rows: rows,
      digest: digest,
      ipc: ipc
    }

  def convert({:transit_frozen, identity, purpose, input, bytes}),
    do: %S.FrozenMutation{
      identity: Client.convert(identity),
      purpose: purpose,
      input: input,
      bytes: bytes
    }

  def convert({:transit_committed, input, receipt}),
    do: %S.Committed{input: input, receipt: Client.convert(receipt)}

  def convert({:transit_blocked, input, receipt}),
    do: %S.Blocked{input: convert(input), receipt: Client.convert(receipt)}

  def convert({:transit_needs_recovery, mutation, phase, error, receipt}),
    do: %S.NeedsRecovery{
      mutation: convert(mutation),
      phase: phase,
      error: Client.convert(error),
      receipt: Client.convert(receipt)
    }

  def convert({:transit_runner_shutdown, pending, event}),
    do: %S.Shutdown{pending: convert(pending), last_event: convert(event)}

  def convert(:undefined), do: nil
  def convert(v), do: Client.convert(v)
  defp origin({:process, body}), do: {:process, %{body | process: Client.convert(body.process)}}
  defp origin(v), do: v
end
