defmodule Transit.Station.Sdk.UnifiedQuery.Column do
  @enforce_keys [:name, :type]
  @derive {Inspect, only: []}
  defstruct [:name, :type]
end

defmodule Transit.Station.Sdk.UnifiedQuery.Decoder do
  @enforce_keys [:type]
  @derive {Inspect, only: []}
  defstruct [:type, version: 1]
end

defmodule Transit.Station.Sdk.UnifiedQuery.KvSource do
  @enforce_keys [:resource, :key, :value]
  @derive {Inspect, only: []}
  defstruct [:resource, :key, :value, prefix: <<>>]
end

defmodule Transit.Station.Sdk.UnifiedQuery.TableSource do
  @enforce_keys [:resource, :id, :value_type]
  @derive {Inspect, only: []}
  defstruct [:resource, :id, :value_type, names: ["id", "value"]]
end

defmodule Transit.Station.Sdk.UnifiedQuery.Projection do
  @enforce_keys [:column]
  @derive {Inspect, only: []}
  defstruct [
    :column,
    path: [],
    relative: false,
    mode: :scalar,
    text_bytes: 4096,
    text_steps: 4096
  ]
end

defmodule Transit.Station.Sdk.UnifiedQuery.DocumentSource do
  @enforce_keys [:reference, :projections]
  @derive {Inspect, only: []}
  defstruct [:reference, :projections, expand: nil]
end

defmodule Transit.Station.Sdk.UnifiedQuery.PredicateProgram do
  @enforce_keys [:instructions]
  @derive {Inspect, only: []}
  defstruct [:instructions]
end

defmodule Transit.Station.Sdk.UnifiedQuery.Plan do
  @enforce_keys [:projection]
  @derive {Inspect, only: []}
  defstruct [:projection, predicate: :all, aggregate: :rows, limit: nil, output_names: nil]
end

defmodule Transit.Station.Sdk.UnifiedQuery.Budgets do
  @enforce_keys [:pages, :segments, :result_bytes]
  @derive {Inspect, only: []}
  defstruct [:pages, :segments, :result_bytes]
end

defmodule Transit.Station.Sdk.UnifiedQuery.Bundle do
  @enforce_keys [:bytes]
  @derive {Inspect, only: []}
  defstruct [:bytes]
end

defmodule Transit.Station.Sdk.UnifiedQuery.Prepared do
  @enforce_keys [:bytes]
  @derive {Inspect, only: []}
  defstruct [:bytes]
end

defmodule Transit.Station.Sdk.UnifiedQuery.Cursor do
  @enforce_keys [:opaque]
  @derive {Inspect, only: []}
  defstruct [:opaque]
end

defmodule Transit.Station.Sdk.UnifiedQuery.Connection do
  @enforce_keys [:source, :resource, :requester, :requests]
  @derive {Inspect, only: []}
  defstruct [:source, :resource, :requester, :requests]
end

defmodule Transit.Station.Sdk.UnifiedQuery.Description do
  @enforce_keys [
    :resource_revision,
    :policy_revision,
    :budgets,
    :bundle_bytes,
    :segment_bytes,
    :batch_rows
  ]
  @derive {Inspect, only: []}
  defstruct [
    :resource_revision,
    :policy_revision,
    :budgets,
    :bundle_bytes,
    :segment_bytes,
    :batch_rows,
    active: nil
  ]
end

defmodule Transit.Station.Sdk.UnifiedQuery.SourceDescription do
  @enforce_keys [:columns]
  defstruct [:columns]
end

defmodule Transit.Station.Sdk.UnifiedQuery.TableListing do
  @enforce_keys [:names]
  defstruct [:names]
end

defmodule Transit.Station.Sdk.UnifiedQuery.Explanation do
  @enforce_keys [:operators, :predicate, :projection, :aggregate, :columns, :budgets]
  defstruct [:operators, :predicate, :projection, :aggregate, :columns, :budgets, limit: nil]
end

defmodule Transit.Station.Sdk.UnifiedQuery.Inspection do
  @enforce_keys [
    :name,
    :resource,
    :source_kind,
    :source_digest,
    :schema_digest,
    :resource_revision,
    :policy_revision,
    :details
  ]
  @derive {Inspect, only: [:name, :source_kind]}
  defstruct [
    :name,
    :resource,
    :source_kind,
    :source_digest,
    :schema_digest,
    :resource_revision,
    :policy_revision,
    :details
  ]
end

defmodule Transit.Station.Sdk.UnifiedQuery.Status do
  @enforce_keys [:phase, :correlation, :reference]
  @derive {Inspect, only: []}
  defstruct [:phase, :correlation, :reference, manifest: nil, collected: false]
end

defmodule Transit.Station.Sdk.UnifiedQuery.Observation do
  @enforce_keys [:state]
  @derive {Inspect, only: []}
  defstruct [:state, reason: nil]
end

defmodule Transit.Station.Sdk.UnifiedQuery.Alternative do
  @enforce_keys [:counter, :replica, :value]
  @derive {Inspect, only: []}
  defstruct [:counter, :replica, :value]
end

defmodule Transit.Station.Sdk.UnifiedQuery.Manifest do
  @enforce_keys [
    :job,
    :source,
    :requester,
    :correlation,
    :policy_revision,
    :request,
    :kind,
    :resource,
    :revision,
    :source_digest,
    :schema_digest,
    :plan_digest,
    :pages,
    :scanned,
    :selected,
    :value_count,
    :segments,
    :rows,
    :byte_count,
    :finished,
    :chain
  ]
  @derive {Inspect, only: []}
  defstruct [
    :job,
    :source,
    :requester,
    :correlation,
    :policy_revision,
    :request,
    :kind,
    :resource,
    :revision,
    :source_digest,
    :schema_digest,
    :plan_digest,
    :pages,
    :scanned,
    :selected,
    :value_count,
    :segments,
    :rows,
    :byte_count,
    :finished,
    :chain,
    sum: nil
  ]
end

defmodule Transit.Station.Sdk.UnifiedQuery.Page do
  @enforce_keys [:manifest, :columns, :ordinal, :rows, :ipc]
  @derive {Inspect, only: []}
  defstruct [:manifest, :columns, :ordinal, :rows, :ipc, next: nil]
end

defmodule Transit.Station.Sdk.UnifiedQuery do
  @moduledoc """
  Explicit v1 immutable sources, plans and signed query callers. Closing joins
  owned native work; killing a waiting task does not cancel a durable query.
  Persist Prepared.bytes before submit and retry identical bytes on uncertainty.
  """
  alias Transit.Client
  alias Transit.Station.Sdk.{Runner, Value, Document}

  alias __MODULE__.{
    Column,
    Decoder,
    KvSource,
    TableSource,
    Projection,
    DocumentSource,
    PredicateProgram,
    Plan,
    Budgets,
    Bundle,
    Prepared,
    Cursor,
    Connection,
    Description,
    SourceDescription,
    TableListing,
    Explanation,
    Inspection,
    Status,
    Observation,
    Alternative,
    Manifest,
    Page
  }

  def prepare(source, %Plan{} = plan, %Budgets{} = budgets, native_host \\ nil) do
    with :ok <- Runner.compatible(),
         do:
           result(
             :transit_unified_query.prepare(
               native(source),
               native(plan),
               native(budgets),
               Value.optional(native_host)
             )
           )
  end

  def decode_arrow(columns, ipc, rows, native_host \\ nil) do
    with :ok <- Runner.compatible(),
         do:
           result(
             :transit_unified_query.decode_arrow(
               native(columns),
               ipc,
               rows,
               Value.optional(native_host)
             )
           )
  end

  def open(
        %Client.Config{} = config,
        %Client.Credential{} = credential,
        %Connection{} = connection
      ) do
    with :ok <- Runner.compatible(),
         do:
           result(
             :transit_unified_query.open(
               Client.native(config),
               Client.native(credential),
               native(connection)
             )
           )
  end

  def close(client), do: result(:transit_unified_query.close(client))

  def describe(client, source),
    do: result(:transit_unified_query.describe(client, native(source)))

  def inspect_sql(client, source, name, sql, %Budgets{} = budgets),
    do:
      result(
        :transit_unified_query.inspect_sql(client, native(source), name, sql, native(budgets))
      )

  def prepare_next(client, namespace, %Bundle{} = bundle),
    do: result(:transit_unified_query.prepare_next(client, namespace, native(bundle)))

  def prepare_control(client, control, namespace),
    do: result(:transit_unified_query.prepare_control(client, control, namespace))

  def submit(client, %Prepared{} = prepared),
    do: result(:transit_unified_query.submit(client, native(prepared)))

  def observe(client, input), do: result(:transit_unified_query.observe(client, input))
  def status(client, namespace), do: result(:transit_unified_query.status(client, namespace))

  def page(client, namespace, cursor \\ nil),
    do: result(:transit_unified_query.page(client, namespace, native(cursor)))

  defp result({:ok, value}), do: {:ok, convert(value)}

  defp result({:uncertain, prepared, error}),
    do: {:uncertain, convert(prepared), Client.convert(error)}

  defp result(error), do: Client.convert(error)

  @doc false
  def native(%Column{} = v), do: {:transit_unified_column, native(v.name), native(v.type)}
  def native(%Decoder{} = v), do: {:transit_unified_decoder, native(v.type), native(v.version)}

  def native(%KvSource{} = v),
    do:
      {:transit_unified_kv, native(v.resource), native(v.prefix), native(v.key), native(v.value)}

  def native(%TableSource{} = v),
    do:
      {:transit_unified_table, native(v.resource), native(v.id), native(v.names),
       native(v.value_type)}

  def native(%Projection{} = v),
    do:
      {:transit_unified_projection, native(v.column), native(v.path), native(v.relative),
       native(v.mode), native(v.text_bytes), native(v.text_steps)}

  def native(%DocumentSource{} = v),
    do: {:transit_unified_document, native(v.reference), native(v.projections), native(v.expand)}

  def native(%PredicateProgram{} = v),
    do: {:transit_unified_predicate_program, native(v.instructions)}

  def native(%Plan{} = v),
    do:
      {:transit_unified_plan, native(v.projection), native(v.predicate), native(v.aggregate),
       native(v.limit), native(v.output_names)}

  def native(%Budgets{} = v),
    do: {:transit_unified_budgets, native(v.pages), native(v.segments), native(v.result_bytes)}

  def native(%Bundle{} = v), do: {:transit_unified_bundle, native(v.bytes)}
  def native(%Prepared{} = v), do: {:transit_unified_prepared, native(v.bytes)}
  def native(%Cursor{} = v), do: {:transit_unified_cursor, native(v.opaque)}

  def native(%Connection{} = v),
    do:
      {:transit_unified_connection, native(v.source), native(v.resource), native(v.requester),
       native(v.requests)}

  def native(%Description{} = v),
    do:
      {:transit_unified_description, native(v.resource_revision), native(v.policy_revision),
       native(v.budgets), native(v.active), native(v.bundle_bytes), native(v.segment_bytes),
       native(v.batch_rows)}

  def native(%Status{} = v),
    do:
      {:transit_unified_status, native(v.phase), native(v.correlation), native(v.reference),
       native(v.manifest), native(v.collected)}

  def native(%Observation{} = v),
    do: {:transit_unified_observation, native(v.state), native(v.reason)}

  def native(%Alternative{} = v),
    do: {:transit_unified_alternative, native(v.counter), native(v.replica), native(v.value)}

  def native(%Manifest{} = v),
    do:
      {:transit_unified_manifest, native(v.job), native(v.source), native(v.requester),
       native(v.correlation), native(v.policy_revision), native(v.request), native(v.kind),
       native(v.resource), native(v.revision), native(v.source_digest), native(v.schema_digest),
       native(v.plan_digest), native(v.pages), native(v.scanned), native(v.selected),
       native(v.value_count), native(v.segments), native(v.rows), native(v.byte_count),
       native(v.sum), native(v.finished), native(v.chain)}

  def native(%Page{} = v),
    do:
      {:transit_unified_page, native(v.manifest), native(v.columns), native(v.ordinal),
       native(v.rows), native(v.ipc), native(v.next)}

  def native(%SourceDescription{} = v),
    do: {:transit_unified_source_description, native(v.columns)}

  def native(%TableListing{} = v), do: {:transit_unified_table_listing, native(v.names)}

  def native(%Explanation{} = v),
    do:
      {:transit_unified_explanation, native(v.operators), native(v.predicate),
       native(v.projection), native(v.limit), native(v.aggregate), native(v.columns),
       native(v.budgets)}

  def native(%Inspection{} = v),
    do:
      {:transit_unified_inspection, native(v.name), native(v.resource), native(v.source_kind),
       native(v.source_digest), native(v.schema_digest), native(v.resource_revision),
       native(v.policy_revision), native(v.details)}

  def native(%Transit.Station.Sdk.ReadVersion{} = v), do: Value.native(v)
  def native(%Client.AdmissionReceipt{position: p}), do: {:transit_admission, p}

  def native(%Document.Reference{} = v), do: Document.native(v)
  def native(%Client.ResourceRef{} = v), do: Client.native(v)
  def native(%Client.ProcessRef{} = v), do: Client.native(v)
  def native(nil), do: :undefined
  def native(values) when is_list(values), do: Enum.map(values, &native/1)

  def native(value) when is_tuple(value),
    do: value |> Tuple.to_list() |> Enum.map(&native/1) |> List.to_tuple()

  def native(value), do: value

  @doc false
  def convert({:transit_unified_predicate_program, instructions}),
    do: %PredicateProgram{instructions: convert(instructions)}

  def convert({:transit_unified_column, name, type}),
    do: %Column{name: convert(name), type: convert(type)}

  def convert({:transit_unified_decoder, type, version}),
    do: %Decoder{type: convert(type), version: convert(version)}

  def convert({:transit_unified_kv, resource, prefix, key, value}),
    do: %KvSource{
      resource: convert(resource),
      prefix: convert(prefix),
      key: convert(key),
      value: convert(value)
    }

  def convert({:transit_unified_table, resource, id, names, value_type}),
    do: %TableSource{
      resource: convert(resource),
      id: convert(id),
      names: convert(names),
      value_type: convert(value_type)
    }

  def convert(
        {:transit_unified_projection, column, path, relative, mode, text_bytes, text_steps}
      ),
      do: %Projection{
        column: convert(column),
        path: convert(path),
        relative: convert(relative),
        mode: convert(mode),
        text_bytes: convert(text_bytes),
        text_steps: convert(text_steps)
      }

  def convert({:transit_unified_document, reference, projections, expand}),
    do: %DocumentSource{
      reference: convert(reference),
      projections: convert(projections),
      expand: convert(expand)
    }

  def convert({:transit_unified_plan, projection, predicate, aggregate, limit, output_names}),
    do: %Plan{
      projection: convert(projection),
      predicate: convert(predicate),
      aggregate: convert(aggregate),
      limit: convert(limit),
      output_names: convert(output_names)
    }

  def convert({:transit_unified_budgets, pages, segments, result_bytes}),
    do: %Budgets{
      pages: convert(pages),
      segments: convert(segments),
      result_bytes: convert(result_bytes)
    }

  def convert({:transit_unified_bundle, bytes}), do: %Bundle{bytes: convert(bytes)}
  def convert({:transit_unified_prepared, bytes}), do: %Prepared{bytes: convert(bytes)}
  def convert({:transit_unified_cursor, opaque}), do: %Cursor{opaque: convert(opaque)}

  def convert({:transit_unified_connection, source, resource, requester, requests}),
    do: %Connection{
      source: convert(source),
      resource: convert(resource),
      requester: convert(requester),
      requests: convert(requests)
    }

  def convert(
        {:transit_unified_description, resource_revision, policy_revision, budgets, active,
         bundle_bytes, segment_bytes, batch_rows}
      ),
      do: %Description{
        resource_revision: convert(resource_revision),
        policy_revision: convert(policy_revision),
        budgets: convert(budgets),
        active: convert(active),
        bundle_bytes: convert(bundle_bytes),
        segment_bytes: convert(segment_bytes),
        batch_rows: convert(batch_rows)
      }

  def convert({:transit_unified_status, phase, correlation, reference, manifest, collected}),
    do: %Status{
      phase: convert(phase),
      correlation: convert(correlation),
      reference: convert(reference),
      manifest: convert(manifest),
      collected: convert(collected)
    }

  def convert({:transit_unified_source_description, columns}),
    do: %SourceDescription{columns: convert(columns)}

  def convert({:transit_unified_table_listing, names}), do: %TableListing{names: convert(names)}

  def convert(
        {:transit_unified_explanation, operators, predicate, projection, limit, aggregate,
         columns, budgets}
      ),
      do: %Explanation{
        operators: convert(operators),
        predicate: convert(predicate),
        projection: convert(projection),
        limit: convert(limit),
        aggregate: convert(aggregate),
        columns: convert(columns),
        budgets: convert(budgets)
      }

  def convert(
        {:transit_unified_inspection, name, resource, source_kind, source_digest, schema_digest,
         resource_revision, policy_revision, details}
      ),
      do: %Inspection{
        name: convert(name),
        resource: convert(resource),
        source_kind: convert(source_kind),
        source_digest: convert(source_digest),
        schema_digest: convert(schema_digest),
        resource_revision: convert(resource_revision),
        policy_revision: convert(policy_revision),
        details: convert(details)
      }

  def convert({:transit_unified_observation, state, reason}),
    do: %Observation{state: convert(state), reason: convert(reason)}

  def convert({:transit_unified_alternative, counter, replica, value}),
    do: %Alternative{counter: convert(counter), replica: convert(replica), value: convert(value)}

  def convert(
        {:transit_unified_manifest, job, source, requester, correlation, policy_revision, request,
         kind, resource, revision, source_digest, schema_digest, plan_digest, pages, scanned,
         selected, value_count, segments, rows, byte_count, sum, finished, chain}
      ),
      do: %Manifest{
        job: convert(job),
        source: convert(source),
        requester: convert(requester),
        correlation: convert(correlation),
        policy_revision: convert(policy_revision),
        request: convert(request),
        kind: convert(kind),
        resource: convert(resource),
        revision: convert(revision),
        source_digest: convert(source_digest),
        schema_digest: convert(schema_digest),
        plan_digest: convert(plan_digest),
        pages: convert(pages),
        scanned: convert(scanned),
        selected: convert(selected),
        value_count: convert(value_count),
        segments: convert(segments),
        rows: convert(rows),
        byte_count: convert(byte_count),
        sum: convert(sum),
        finished: convert(finished),
        chain: convert(chain)
      }

  def convert({:transit_unified_page, manifest, columns, ordinal, rows, ipc, next}),
    do: %Page{
      manifest: convert(manifest),
      columns: convert(columns),
      ordinal: convert(ordinal),
      rows: convert(rows),
      ipc: convert(ipc),
      next: convert(next)
    }

  def convert({:transit_unified_client, _} = v), do: v
  def convert({:transit_read_version, _, _, _} = v), do: Value.convert(v)
  def convert({:transit_document_reference, _, _, _, _, _} = v), do: Document.convert(v)
  def convert({:transit_resource, _, _} = v), do: Client.convert(v)
  def convert({:transit_process, _, _} = v), do: Client.convert(v)
  def convert({:transit_admission, _} = v), do: Client.convert(v)
  def convert(:undefined), do: nil
  def convert(values) when is_list(values), do: Enum.map(values, &convert/1)

  def convert(value) when is_tuple(value),
    do: value |> Tuple.to_list() |> Enum.map(&convert/1) |> List.to_tuple()

  def convert(value), do: value
end
