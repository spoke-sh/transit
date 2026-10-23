defmodule Transit.Station.Sdk.Catalog.Subject do
  @enforce_keys [:principal, :login_role, :role, :credential_epoch, :audience, :context]
  @derive {Inspect, only: []}
  defstruct [:principal, :login_role, :role, :credential_epoch, :audience, :context]
end

defmodule Transit.Station.Sdk.Catalog.Authority do
  @enforce_keys [
    :database_domain,
    :schema_domain,
    :table_domain,
    :database,
    :initial_schema_authority,
    :initial_schema
  ]
  @derive {Inspect, only: []}
  defstruct [
    :database_domain,
    :schema_domain,
    :table_domain,
    :database,
    :initial_schema_authority,
    :initial_schema
  ]
end

defmodule Transit.Station.Sdk.Catalog.Scope do
  @enforce_keys [:resource, :catalog]
  @derive {Inspect, only: []}
  defstruct [:resource, :catalog]
end

defmodule Transit.Station.Sdk.Catalog.Connection do
  @enforce_keys [:owner, :scope]
  @derive {Inspect, only: []}
  defstruct [:owner, :scope, role: nil, namespace: 1]
end

defmodule Transit.Station.Sdk.Catalog.TableLimits do
  @enforce_keys [:record_bytes, :staging_bytes, :staging_records]
  @derive {Inspect, only: []}
  defstruct [:record_bytes, :staging_bytes, :staging_records]
end

defmodule Transit.Station.Sdk.Catalog.Configuration do
  @enforce_keys [:scope, :owner, :administrator, :table_limits, :authority, :database_name]
  @derive {Inspect, only: []}
  defstruct [:scope, :owner, :administrator, :table_limits, :authority, :database_name]
end

defmodule Transit.Station.Sdk.Catalog.Column do
  @enforce_keys [:id, :name, :type]
  @derive {Inspect, only: []}
  defstruct [
    :id,
    :name,
    :type,
    nullable: true,
    default: nil,
    max_characters: nil,
    encoding: :plain,
    collation: :none
  ]
end

defmodule Transit.Station.Sdk.Catalog.Schema do
  @enforce_keys [:object, :revision, :next_column, :columns]
  @derive {Inspect, only: []}
  defstruct [:object, :revision, :next_column, :columns, primary_key: []]
end

defmodule Transit.Station.Sdk.Catalog.Identity do
  @enforce_keys [:operation, :namespace]
  @derive {Inspect, only: []}
  defstruct [:operation, :namespace]
end

defmodule Transit.Station.Sdk.Catalog.Basis do
  @enforce_keys [:object, :revision, :schema_fingerprint]
  @derive {Inspect, only: []}
  defstruct [:object, :revision, :schema_fingerprint]
end

defmodule Transit.Station.Sdk.Catalog.MetadataCommitment do
  @enforce_keys [:bytes, :digest]
  @derive {Inspect, only: []}
  defstruct [:bytes, :digest]
end

defmodule Transit.Station.Sdk.Catalog.Metadata do
  @enforce_keys [
    :scope,
    :namespace,
    :object,
    :revision,
    :name,
    :schema_fingerprint,
    :principal,
    :operation,
    :admitted_input,
    :commitment
  ]
  @derive {Inspect, only: []}
  defstruct [
    :scope,
    :namespace,
    :object,
    :revision,
    :name,
    :schema_fingerprint,
    :principal,
    :operation,
    :admitted_input,
    :commitment
  ]
end

defmodule Transit.Station.Sdk.Catalog.Head do
  @enforce_keys [:revision, :rows, :pending]
  @derive {Inspect, only: []}
  defstruct [:revision, :rows, :pending]
end

defmodule Transit.Station.Sdk.Catalog.Entry do
  @enforce_keys [:metadata, :head]
  @derive {Inspect, only: []}
  defstruct [:metadata, :head]
end

defmodule Transit.Station.Sdk.Catalog.Definition do
  @enforce_keys [:metadata, :head, :schema, :authorization]
  @derive {Inspect, only: []}
  defstruct [:metadata, :head, :schema, :authorization]
end

defmodule Transit.Station.Sdk.Catalog.HistoricalDefinition do
  @enforce_keys [:metadata, :schema]
  @derive {Inspect, only: []}
  defstruct [:metadata, :schema]
end

defmodule Transit.Station.Sdk.Catalog.Cursor do
  @enforce_keys [:definition, :scope, :resource_revision, :after_object]
  @derive {Inspect, only: []}
  defstruct [:definition, :scope, :resource_revision, :after_object]
end

defmodule Transit.Station.Sdk.Catalog.Page do
  @enforce_keys [:resource_revision, :entries]
  @derive {Inspect, only: []}
  defstruct [:resource_revision, :entries, next: nil]
end

defmodule Transit.Station.Sdk.Catalog.Reference do
  @enforce_keys [:definition, :digest]
  @derive {Inspect, only: []}
  defstruct [:definition, :digest]
end

defmodule Transit.Station.Sdk.Catalog.SavedIntent do
  @enforce_keys [:definition, :bytes]
  @derive {Inspect, only: []}
  defstruct [:definition, :bytes]
end

defmodule Transit.Station.Sdk.Catalog.Prepared do
  @enforce_keys [:bytes]
  @derive {Inspect, only: []}
  defstruct [:bytes]
end

defmodule Transit.Station.Sdk.Catalog.Intent do
  @enforce_keys [:reference, :scope, :owner, :principal, :identity, :object, :kind]
  @derive {Inspect, only: []}
  defstruct [:reference, :scope, :owner, :principal, :identity, :object, :kind]
end

defmodule Transit.Station.Sdk.Catalog.Compiled do
  @enforce_keys [:intent, :saved]
  @derive {Inspect, only: []}
  defstruct [:intent, :saved]
end

defmodule Transit.Station.Sdk.Catalog.Counts do
  @enforce_keys [:matched, :changed]
  @derive {Inspect, only: []}
  defstruct [:matched, :changed]
end

defmodule Transit.Station.Sdk.Catalog.Outcome do
  @enforce_keys [:kind, :operation, :object, :phase, :terminal, :admitted_input, :diagnostic]
  @derive {Inspect, only: []}
  defstruct [
    :kind,
    :operation,
    :object,
    :phase,
    :terminal,
    :admitted_input,
    :diagnostic,
    actual_object: nil,
    counts: nil,
    completed_input: nil
  ]
end

defmodule Transit.Station.Sdk.Catalog.Upload do
  @enforce_keys [:phase, :received, :total]
  @derive {Inspect, only: []}
  defstruct [:phase, :received, :total]
end

defmodule Transit.Station.Sdk.Catalog.State do
  @enforce_keys []
  @derive {Inspect, only: []}
  defstruct outcome: nil, upload: nil
end

defmodule Transit.Station.Sdk.Catalog.Disposition do
  @enforce_keys [:input, :outcome, :diagnostic]
  @derive {Inspect, only: []}
  defstruct [:input, :outcome, :diagnostic]
end

defmodule Transit.Station.Sdk.Catalog.Next do
  @enforce_keys [:kind]
  @derive {Inspect, only: []}
  defstruct [:kind, prepared: nil, outcome: nil]
end

defmodule Transit.Station.Sdk.Catalog.Progress do
  @enforce_keys [:observation]
  @derive {Inspect, only: []}
  defstruct [:observation, disposition: nil, outcome: nil, upload: nil]
end

defmodule Transit.Station.Sdk.Catalog.Capabilities do
  @enforce_keys [
    :version,
    :definition,
    :max_columns,
    :max_rows,
    :max_sql_bytes,
    :max_intent_bytes,
    :max_action_bytes,
    :max_prepared_bytes,
    :resident_intents
  ]
  @derive {Inspect, only: []}
  defstruct [
    :version,
    :definition,
    :max_columns,
    :max_rows,
    :max_sql_bytes,
    :max_intent_bytes,
    :max_action_bytes,
    :max_prepared_bytes,
    :resident_intents
  ]
end

defmodule Transit.Station.Sdk.Catalog.Description do
  @enforce_keys [:configuration, :subject, :authorization_revision, :resource_revision]
  @derive {Inspect, only: []}
  defstruct [:configuration, :subject, :authorization_revision, :resource_revision]
end

defmodule Transit.Station.Sdk.Catalog.Assignment do
  @enforce_keys [:column, :value]
  @derive {Inspect, only: []}
  defstruct [:column, :value]
end

defmodule Transit.Station.Sdk.Catalog.Dependency do
  @enforce_keys [:scope, :object, :identity, :owner, :kind]
  @derive {Inspect, only: []}
  defstruct [:scope, :object, :identity, :owner, :kind]
end

defmodule Transit.Station.Sdk.Catalog do
  @moduledoc """
  General Table schemas, lifecycle and exact recovery through the shared Erlang
  worker and Zig owner. Persist SavedIntent before progression and Prepared
  before each submission. Task loss does not cancel admitted work.
  """
  alias Transit.Client
  alias Transit.Station.Sdk.{Logical, Runner}

  alias __MODULE__.{
    Scope,
    Connection,
    TableLimits,
    Configuration,
    Authority,
    Subject,
    Column,
    Schema,
    Identity,
    Basis,
    Metadata,
    MetadataCommitment,
    Head,
    Entry,
    Definition,
    HistoricalDefinition,
    Cursor,
    Page,
    Reference,
    SavedIntent,
    Prepared,
    Intent,
    Compiled,
    Counts,
    Outcome,
    Upload,
    State,
    Disposition,
    Next,
    Progress,
    Capabilities,
    Description,
    Assignment,
    Dependency
  }

  def open(
        %Client.Config{} = config,
        %Client.Credential{} = credential,
        %Connection{} = connection,
        table_service_url \\ nil
      ) do
    with :ok <- Runner.compatible(),
         do:
           request(fn ->
             :transit_catalog.open(
               Client.native(config),
               Client.native(credential),
               native(connection),
               native(table_service_url)
             )
           end)
  end

  def close(client), do: result(:transit_catalog.close(client))
  def capabilities(client), do: request(fn -> :transit_catalog.capabilities(client) end)
  def describe(client), do: request(fn -> :transit_catalog.describe(client) end)
  def lookup(client, name), do: request(fn -> :transit_catalog.lookup(client, name) end)

  def definition(client, object, revision),
    do: request(fn -> :transit_catalog.definition(client, object, revision) end)

  def list(client, cursor \\ nil),
    do: request(fn -> :transit_catalog.list(client, native(cursor)) end)

  def compile_sql(client, sql, identity, create_object \\ nil),
    do:
      request(fn ->
        :transit_catalog.compile_sql(client, sql, native(identity), native(create_object))
      end)

  def prepare(client, name, identity, operation),
    do:
      request(fn ->
        :transit_catalog.prepare(client, name, native(identity), native(operation))
      end)

  def load(client, saved), do: request(fn -> :transit_catalog.load(client, native(saved)) end)

  def forget(client, reference),
    do: request(fn -> :transit_catalog.forget(client, native(reference)) end)

  def next(client, reference),
    do: request(fn -> :transit_catalog.next(client, native(reference)) end)

  def status(client, reference),
    do: request(fn -> :transit_catalog.status(client, native(reference)) end)

  def prepare_resume(client, reference),
    do: request(fn -> :transit_catalog.prepare_resume(client, native(reference)) end)

  def prepare_control(client, reference, control),
    do: request(fn -> :transit_catalog.prepare_control(client, native(reference), control) end)

  def prepare_initialize(client, configuration),
    do: request(fn -> :transit_catalog.prepare_initialize(client, native(configuration)) end)

  def prepare_dependency(client, dependency, present),
    do:
      request(fn -> :transit_catalog.prepare_dependency(client, native(dependency), present) end)

  def submit(client, prepared),
    do: request(fn -> :transit_catalog.submit(client, native(prepared)) end)

  def observe(client, prepared, input, wait \\ false),
    do: request(fn -> :transit_catalog.observe(client, native(prepared), input, wait) end)

  def input_disposition(client, prepared, input),
    do: request(fn -> :transit_catalog.input_disposition(client, native(prepared), input) end)

  def progress(client, reference, prepared, input, wait \\ false),
    do:
      request(fn ->
        :transit_catalog.progress(client, native(reference), native(prepared), input, wait)
      end)

  def basis(%Metadata{} = metadata), do: convert(:transit_catalog.basis(native(metadata)))

  defp request(fun) do
    fun.() |> result()
  rescue
    ArgumentError -> {:error, %Client.Error{kind: :invalid_argument, phase: :catalog_value}}
  end

  defp result({:ok, value}), do: {:ok, convert(value)}

  defp result({:uncertain, prepared, error}),
    do: {:uncertain, convert(prepared), Client.convert(error)}

  defp result(error), do: Client.convert(error)
  @doc false
  def native(value), do: project(value, :native)
  @doc false
  def convert(value), do: project(value, :public)

  defp project(value, direction) do
    {result, _} = walk(value, direction, 0, 1_000_000)
    result
  end

  defp walk(_, _, depth, left) when depth > 96 or left <= 0,
    do: raise(ArgumentError, "Catalog projection bound")

  defp walk({:transit_catalog_client, _, _} = handle, _, _, left), do: {handle, left - 1}

  defp walk(%Scope{} = v, :native, depth, left),
    do: tagged(:transit_catalog_scope, [v.resource, v.catalog], :native, depth, left)

  defp walk(%Authority{} = v, :native, depth, left),
    do:
      tagged(
        :transit_catalog_authority,
        [
          v.database_domain,
          v.schema_domain,
          v.table_domain,
          v.database,
          v.initial_schema_authority,
          v.initial_schema
        ],
        :native,
        depth,
        left
      )

  defp walk(%Subject{} = v, :native, depth, left),
    do:
      tagged(
        :transit_catalog_subject,
        [v.principal, v.login_role, v.role, v.credential_epoch, v.audience, v.context],
        :native,
        depth,
        left
      )

  defp walk(%Connection{} = v, :native, depth, left),
    do:
      tagged(
        :transit_catalog_connection,
        [v.owner, v.scope, v.role, v.namespace],
        :native,
        depth,
        left
      )

  defp walk(%TableLimits{} = v, :native, depth, left),
    do:
      tagged(
        :transit_catalog_limits,
        [v.record_bytes, v.staging_bytes, v.staging_records],
        :native,
        depth,
        left
      )

  defp walk(%Configuration{} = v, :native, depth, left),
    do:
      tagged(
        :transit_catalog_configuration,
        [v.scope, v.owner, v.administrator, v.table_limits, v.authority, v.database_name],
        :native,
        depth,
        left
      )

  defp walk(%Column{} = v, :native, depth, left),
    do:
      tagged(
        :transit_catalog_column,
        [v.id, v.name, v.type, v.nullable, v.default, v.max_characters, v.encoding, v.collation],
        :native,
        depth,
        left
      )

  defp walk(%Schema{} = v, :native, depth, left),
    do:
      tagged(
        :transit_catalog_schema,
        [v.object, v.revision, v.next_column, v.columns, v.primary_key],
        :native,
        depth,
        left
      )

  defp walk(%Identity{} = v, :native, depth, left),
    do: tagged(:transit_catalog_identity, [v.operation, v.namespace], :native, depth, left)

  defp walk(%Basis{} = v, :native, depth, left),
    do:
      tagged(
        :transit_catalog_basis,
        [v.object, v.revision, v.schema_fingerprint],
        :native,
        depth,
        left
      )

  defp walk(%MetadataCommitment{} = v, :native, depth, left),
    do: tagged(:transit_catalog_metadata_commitment, [v.bytes, v.digest], :native, depth, left)

  defp walk(%Metadata{} = v, :native, depth, left),
    do:
      tagged(
        :transit_catalog_metadata,
        [
          v.scope,
          v.namespace,
          v.object,
          v.revision,
          v.name,
          v.schema_fingerprint,
          v.principal,
          v.operation,
          v.admitted_input,
          v.commitment
        ],
        :native,
        depth,
        left
      )

  defp walk(%Head{} = v, :native, depth, left),
    do: tagged(:transit_catalog_head, [v.revision, v.rows, v.pending], :native, depth, left)

  defp walk(%Entry{} = v, :native, depth, left),
    do: tagged(:transit_catalog_entry, [v.metadata, v.head], :native, depth, left)

  defp walk(%Definition{} = v, :native, depth, left),
    do:
      tagged(
        :transit_catalog_definition,
        [v.metadata, v.head, v.schema, v.authorization],
        :native,
        depth,
        left
      )

  defp walk(%HistoricalDefinition{} = v, :native, depth, left),
    do:
      tagged(:transit_catalog_historical_definition, [v.metadata, v.schema], :native, depth, left)

  defp walk(%Cursor{} = v, :native, depth, left),
    do:
      tagged(
        :transit_catalog_cursor,
        [v.definition, v.scope, v.resource_revision, v.after_object],
        :native,
        depth,
        left
      )

  defp walk(%Page{} = v, :native, depth, left),
    do:
      tagged(
        :transit_catalog_page,
        [v.resource_revision, v.entries, v.next],
        :native,
        depth,
        left
      )

  defp walk(%Reference{} = v, :native, depth, left),
    do: tagged(:transit_catalog_reference, [v.definition, v.digest], :native, depth, left)

  defp walk(%SavedIntent{} = v, :native, depth, left),
    do: tagged(:transit_catalog_saved_intent, [v.definition, v.bytes], :native, depth, left)

  defp walk(%Prepared{} = v, :native, depth, left),
    do: tagged(:transit_catalog_prepared, [v.bytes], :native, depth, left)

  defp walk(%Intent{} = v, :native, depth, left),
    do:
      tagged(
        :transit_catalog_intent,
        [v.reference, v.scope, v.owner, v.principal, v.identity, v.object, v.kind],
        :native,
        depth,
        left
      )

  defp walk(%Compiled{} = v, :native, depth, left),
    do: tagged(:transit_catalog_compiled, [v.intent, v.saved], :native, depth, left)

  defp walk(%Counts{} = v, :native, depth, left),
    do: tagged(:transit_catalog_counts, [v.matched, v.changed], :native, depth, left)

  defp walk(%Outcome{} = v, :native, depth, left),
    do:
      tagged(
        :transit_catalog_outcome,
        [
          v.kind,
          v.operation,
          v.object,
          v.actual_object,
          v.phase,
          v.terminal,
          v.counts,
          v.admitted_input,
          v.completed_input,
          v.diagnostic
        ],
        :native,
        depth,
        left
      )

  defp walk(%Upload{} = v, :native, depth, left),
    do: tagged(:transit_catalog_upload, [v.phase, v.received, v.total], :native, depth, left)

  defp walk(%State{} = v, :native, depth, left),
    do: tagged(:transit_catalog_state, [v.outcome, v.upload], :native, depth, left)

  defp walk(%Disposition{} = v, :native, depth, left),
    do:
      tagged(
        :transit_catalog_disposition,
        [v.input, v.outcome, v.diagnostic],
        :native,
        depth,
        left
      )

  defp walk(%Next{} = v, :native, depth, left),
    do: tagged(:transit_catalog_next, [v.kind, v.prepared, v.outcome], :native, depth, left)

  defp walk(%Progress{} = v, :native, depth, left),
    do:
      tagged(
        :transit_catalog_progress,
        [v.observation, v.disposition, v.outcome, v.upload],
        :native,
        depth,
        left
      )

  defp walk(%Capabilities{} = v, :native, depth, left),
    do:
      tagged(
        :transit_catalog_capabilities,
        [
          v.version,
          v.definition,
          v.max_columns,
          v.max_rows,
          v.max_sql_bytes,
          v.max_intent_bytes,
          v.max_action_bytes,
          v.max_prepared_bytes,
          v.resident_intents
        ],
        :native,
        depth,
        left
      )

  defp walk(%Description{} = v, :native, depth, left),
    do:
      tagged(
        :transit_catalog_description,
        [v.configuration, v.subject, v.authorization_revision, v.resource_revision],
        :native,
        depth,
        left
      )

  defp walk(%Assignment{} = v, :native, depth, left),
    do: tagged(:transit_catalog_assignment, [v.column, v.value], :native, depth, left)

  defp walk(%Dependency{} = v, :native, depth, left),
    do:
      tagged(
        :transit_catalog_dependency,
        [v.scope, v.object, v.identity, v.owner, v.kind],
        :native,
        depth,
        left
      )

  defp walk({:transit_catalog_scope, v0, v1}, :public, depth, left) do
    {[o0, o1], next} = children([v0, v1], :public, depth, left)
    {%Scope{resource: o0, catalog: o1}, next}
  end

  defp walk({:transit_catalog_authority, v0, v1, v2, v3, v4, v5}, :public, depth, left) do
    {[o0, o1, o2, o3, o4, o5], next} = children([v0, v1, v2, v3, v4, v5], :public, depth, left)

    {%Authority{
       database_domain: o0,
       schema_domain: o1,
       table_domain: o2,
       database: o3,
       initial_schema_authority: o4,
       initial_schema: o5
     }, next}
  end

  defp walk({:transit_catalog_subject, v0, v1, v2, v3, v4, v5}, :public, depth, left) do
    {[o0, o1, o2, o3, o4, o5], next} = children([v0, v1, v2, v3, v4, v5], :public, depth, left)

    {%Subject{
       principal: o0,
       login_role: o1,
       role: o2,
       credential_epoch: o3,
       audience: o4,
       context: o5
     }, next}
  end

  defp walk({:transit_catalog_connection, v0, v1, v2, v3}, :public, depth, left) do
    {[o0, o1, o2, o3], next} = children([v0, v1, v2, v3], :public, depth, left)
    {%Connection{owner: o0, scope: o1, role: o2, namespace: o3}, next}
  end

  defp walk({:transit_catalog_limits, v0, v1, v2}, :public, depth, left) do
    {[o0, o1, o2], next} = children([v0, v1, v2], :public, depth, left)
    {%TableLimits{record_bytes: o0, staging_bytes: o1, staging_records: o2}, next}
  end

  defp walk({:transit_catalog_configuration, v0, v1, v2, v3, v4, v5}, :public, depth, left) do
    {[o0, o1, o2, o3, o4, o5], next} = children([v0, v1, v2, v3, v4, v5], :public, depth, left)

    {%Configuration{
       scope: o0,
       owner: o1,
       administrator: o2,
       table_limits: o3,
       authority: o4,
       database_name: o5
     }, next}
  end

  defp walk({:transit_catalog_column, v0, v1, v2, v3, v4, v5, v6, v7}, :public, depth, left) do
    {[o0, o1, o2, o3, o4, o5, o6, o7], next} =
      children([v0, v1, v2, v3, v4, v5, v6, v7], :public, depth, left)

    {%Column{
       id: o0,
       name: o1,
       type: o2,
       nullable: o3,
       default: o4,
       max_characters: o5,
       encoding: o6,
       collation: o7
     }, next}
  end

  defp walk({:transit_catalog_schema, v0, v1, v2, v3, v4}, :public, depth, left) do
    {[o0, o1, o2, o3, o4], next} = children([v0, v1, v2, v3, v4], :public, depth, left)
    {%Schema{object: o0, revision: o1, next_column: o2, columns: o3, primary_key: o4}, next}
  end

  defp walk({:transit_catalog_identity, v0, v1}, :public, depth, left) do
    {[o0, o1], next} = children([v0, v1], :public, depth, left)
    {%Identity{operation: o0, namespace: o1}, next}
  end

  defp walk({:transit_catalog_basis, v0, v1, v2}, :public, depth, left) do
    {[o0, o1, o2], next} = children([v0, v1, v2], :public, depth, left)
    {%Basis{object: o0, revision: o1, schema_fingerprint: o2}, next}
  end

  defp walk({:transit_catalog_metadata_commitment, bytes, digest}, :public, depth, left) do
    {[bytes, digest], next} = children([bytes, digest], :public, depth, left)
    {%MetadataCommitment{bytes: bytes, digest: digest}, next}
  end

  defp walk(
         {:transit_catalog_metadata, v0, v1, v2, v3, v4, v5, v6, v7, v8, v9},
         :public,
         depth,
         left
       ) do
    {[o0, o1, o2, o3, o4, o5, o6, o7, o8, o9], next} =
      children([v0, v1, v2, v3, v4, v5, v6, v7, v8, v9], :public, depth, left)

    {%Metadata{
       scope: o0,
       namespace: o1,
       object: o2,
       revision: o3,
       name: o4,
       schema_fingerprint: o5,
       principal: o6,
       operation: o7,
       admitted_input: o8,
       commitment: o9
     }, next}
  end

  defp walk({:transit_catalog_head, v0, v1, v2}, :public, depth, left) do
    {[o0, o1, o2], next} = children([v0, v1, v2], :public, depth, left)
    {%Head{revision: o0, rows: o1, pending: o2}, next}
  end

  defp walk({:transit_catalog_entry, v0, v1}, :public, depth, left) do
    {[o0, o1], next} = children([v0, v1], :public, depth, left)
    {%Entry{metadata: o0, head: o1}, next}
  end

  defp walk({:transit_catalog_definition, v0, v1, v2, v3}, :public, depth, left) do
    {[o0, o1, o2, o3], next} = children([v0, v1, v2, v3], :public, depth, left)
    {%Definition{metadata: o0, head: o1, schema: o2, authorization: o3}, next}
  end

  defp walk({:transit_catalog_historical_definition, v0, v1}, :public, depth, left) do
    {[o0, o1], next} = children([v0, v1], :public, depth, left)
    {%HistoricalDefinition{metadata: o0, schema: o1}, next}
  end

  defp walk({:transit_catalog_cursor, v0, v1, v2, v3}, :public, depth, left) do
    {[o0, o1, o2, o3], next} = children([v0, v1, v2, v3], :public, depth, left)
    {%Cursor{definition: o0, scope: o1, resource_revision: o2, after_object: o3}, next}
  end

  defp walk({:transit_catalog_page, v0, v1, v2}, :public, depth, left) do
    {[o0, o1, o2], next} = children([v0, v1, v2], :public, depth, left)
    {%Page{resource_revision: o0, entries: o1, next: o2}, next}
  end

  defp walk({:transit_catalog_reference, v0, v1}, :public, depth, left) do
    {[o0, o1], next} = children([v0, v1], :public, depth, left)
    {%Reference{definition: o0, digest: o1}, next}
  end

  defp walk({:transit_catalog_saved_intent, v0, v1}, :public, depth, left) do
    {[o0, o1], next} = children([v0, v1], :public, depth, left)
    {%SavedIntent{definition: o0, bytes: o1}, next}
  end

  defp walk({:transit_catalog_prepared, v0}, :public, depth, left) do
    {[o0], next} = children([v0], :public, depth, left)
    {%Prepared{bytes: o0}, next}
  end

  defp walk({:transit_catalog_intent, v0, v1, v2, v3, v4, v5, v6}, :public, depth, left) do
    {[o0, o1, o2, o3, o4, o5, o6], next} =
      children([v0, v1, v2, v3, v4, v5, v6], :public, depth, left)

    {%Intent{
       reference: o0,
       scope: o1,
       owner: o2,
       principal: o3,
       identity: o4,
       object: o5,
       kind: o6
     }, next}
  end

  defp walk({:transit_catalog_compiled, v0, v1}, :public, depth, left) do
    {[o0, o1], next} = children([v0, v1], :public, depth, left)
    {%Compiled{intent: o0, saved: o1}, next}
  end

  defp walk({:transit_catalog_counts, v0, v1}, :public, depth, left) do
    {[o0, o1], next} = children([v0, v1], :public, depth, left)
    {%Counts{matched: o0, changed: o1}, next}
  end

  defp walk(
         {:transit_catalog_outcome, v0, v1, v2, v3, v4, v5, v6, v7, v8, v9},
         :public,
         depth,
         left
       ) do
    {[o0, o1, o2, o3, o4, o5, o6, o7, o8, o9], next} =
      children([v0, v1, v2, v3, v4, v5, v6, v7, v8, v9], :public, depth, left)

    {%Outcome{
       kind: o0,
       operation: o1,
       object: o2,
       actual_object: o3,
       phase: o4,
       terminal: o5,
       counts: o6,
       admitted_input: o7,
       completed_input: o8,
       diagnostic: o9
     }, next}
  end

  defp walk({:transit_catalog_upload, v0, v1, v2}, :public, depth, left) do
    {[o0, o1, o2], next} = children([v0, v1, v2], :public, depth, left)
    {%Upload{phase: o0, received: o1, total: o2}, next}
  end

  defp walk({:transit_catalog_state, v0, v1}, :public, depth, left) do
    {[o0, o1], next} = children([v0, v1], :public, depth, left)
    {%State{outcome: o0, upload: o1}, next}
  end

  defp walk({:transit_catalog_disposition, v0, v1, v2}, :public, depth, left) do
    {[o0, o1, o2], next} = children([v0, v1, v2], :public, depth, left)
    {%Disposition{input: o0, outcome: o1, diagnostic: o2}, next}
  end

  defp walk({:transit_catalog_next, v0, v1, v2}, :public, depth, left) do
    {[o0, o1, o2], next} = children([v0, v1, v2], :public, depth, left)
    {%Next{kind: o0, prepared: o1, outcome: o2}, next}
  end

  defp walk({:transit_catalog_progress, v0, v1, v2, v3}, :public, depth, left) do
    {[o0, o1, o2, o3], next} = children([v0, v1, v2, v3], :public, depth, left)
    {%Progress{observation: o0, disposition: o1, outcome: o2, upload: o3}, next}
  end

  defp walk(
         {:transit_catalog_capabilities, v0, v1, v2, v3, v4, v5, v6, v7, v8},
         :public,
         depth,
         left
       ) do
    {[o0, o1, o2, o3, o4, o5, o6, o7, o8], next} =
      children([v0, v1, v2, v3, v4, v5, v6, v7, v8], :public, depth, left)

    {%Capabilities{
       version: o0,
       definition: o1,
       max_columns: o2,
       max_rows: o3,
       max_sql_bytes: o4,
       max_intent_bytes: o5,
       max_action_bytes: o6,
       max_prepared_bytes: o7,
       resident_intents: o8
     }, next}
  end

  defp walk({:transit_catalog_description, v0, v1, v2, v3}, :public, depth, left) do
    {[o0, o1, o2, o3], next} = children([v0, v1, v2, v3], :public, depth, left)

    {%Description{
       configuration: o0,
       subject: o1,
       authorization_revision: o2,
       resource_revision: o3
     }, next}
  end

  defp walk({:transit_catalog_assignment, v0, v1}, :public, depth, left) do
    {[o0, o1], next} = children([v0, v1], :public, depth, left)
    {%Assignment{column: o0, value: o1}, next}
  end

  defp walk({:transit_catalog_dependency, v0, v1, v2, v3, v4}, :public, depth, left) do
    {[o0, o1, o2, o3, o4], next} = children([v0, v1, v2, v3, v4], :public, depth, left)
    {%Dependency{scope: o0, object: o1, identity: o2, owner: o3, kind: o4}, next}
  end

  defp walk(%Client.AdmissionReceipt{position: position}, :native, _, left),
    do: {{:transit_admission, position}, left - 1}

  defp walk(%Client.ProcessRef{} = v, :native, _, left), do: {Client.native(v), left - 1}
  defp walk(%Client.ResourceRef{} = v, :native, _, left), do: {Client.native(v), left - 1}
  defp walk(%Logical.Field{} = v, :native, _, left), do: {Logical.native(v), left - 1}
  defp walk(%Logical.Element{} = v, :native, _, left), do: {Logical.native(v), left - 1}
  defp walk(%Logical.Alternative{} = v, :native, _, left), do: {Logical.native(v), left - 1}
  defp walk({:transit_process, _, _} = v, :public, _, left), do: {Client.convert(v), left - 1}
  defp walk({:transit_resource, _, _} = v, :public, _, left), do: {Client.convert(v), left - 1}
  defp walk({:transit_admission, _} = v, :public, _, left), do: {Client.convert(v), left - 1}

  defp walk({:transit_logical_field, _, _, _, _} = v, :public, _, left),
    do: {Logical.convert(v), left - 1}

  defp walk({:transit_logical_element, _, _} = v, :public, _, left),
    do: {Logical.convert(v), left - 1}

  defp walk({:transit_logical_alternative, _, _, _} = v, :public, _, left),
    do: {Logical.convert(v), left - 1}

  defp walk(nil, :native, _, left), do: {:undefined, left - 1}
  defp walk(:undefined, :public, _, left), do: {nil, left - 1}

  defp walk(values, direction, depth, left) when is_list(values),
    do: children(values, direction, depth, left)

  defp walk(value, direction, depth, left) when is_tuple(value) do
    {values, next} = children(Tuple.to_list(value), direction, depth, left)
    {List.to_tuple(values), next}
  end

  defp walk(value, _, _, left), do: {value, left - 1}

  defp children(values, direction, depth, left),
    do: Enum.map_reduce(values, left - 1, &walk(&1, direction, depth + 1, &2))

  defp tagged(tag, values, direction, depth, left) do
    {result, next} = children(values, direction, depth, left)
    {List.to_tuple([tag | result]), next}
  end
end
