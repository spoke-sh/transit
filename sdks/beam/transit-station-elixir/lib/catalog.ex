defmodule Transit.Station.Sdk.Catalog.Scope do
  @enforce_keys [:resource, :catalog]
  @derive {Inspect, only: []}
  defstruct [:resource, :catalog]
end

defmodule Transit.Station.Sdk.Catalog.TableLimits do
  @enforce_keys [:record_bytes, :staging_bytes, :staging_records]
  @derive {Inspect, only: []}
  defstruct [:record_bytes, :staging_bytes, :staging_records]
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

defmodule Transit.Station.Sdk.Catalog.Subject do
  @enforce_keys [:principal, :login_role, :role, :credential_epoch, :audience, :context]
  @derive {Inspect, only: []}
  defstruct [:principal, :login_role, :role, :credential_epoch, :audience, :context]
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
  @enforce_keys [:object, :revision, :next_column]
  @derive {Inspect, only: []}
  defstruct [:object, :revision, :next_column, columns: [], primary_key: []]
end

defmodule Transit.Station.Sdk.Catalog.Counts do
  @enforce_keys [:matched, :changed]
  @derive {Inspect, only: []}
  defstruct [:matched, :changed]
end

defmodule Transit.Station.Sdk.Catalog.Assignment do
  @enforce_keys [:column, :value]
  @derive {Inspect, only: []}
  defstruct [:column, :value]
end

defmodule Transit.Station.Sdk.Catalog.Connection do
  @enforce_keys [:scope, :audience]
  @derive {Inspect, only: []}
  defstruct [:scope, :audience, branch: 1, role: nil]
end

defmodule Transit.Station.Sdk.Catalog.Configuration do
  @enforce_keys [
    :scope,
    :branch,
    :partition,
    :audience,
    :authority,
    :database_name,
    :initial_schema_name
  ]
  @derive {Inspect, only: []}
  defstruct [
    :scope,
    :branch,
    :partition,
    :audience,
    :authority,
    :database_name,
    :initial_schema_name
  ]
end

defmodule Transit.Station.Sdk.Catalog.Identity do
  @enforce_keys [:operation]
  @derive {Inspect, only: []}
  defstruct [:operation, namespace: 1]
end

defmodule Transit.Station.Sdk.Catalog.Position do
  @enforce_keys [:partition, :next_lsn]
  @derive {Inspect, only: []}
  defstruct [:partition, :next_lsn]
end

defmodule Transit.Station.Sdk.Catalog.ObjectIdentity do
  @enforce_keys [:scope, :branch, :object]
  @derive {Inspect, only: []}
  defstruct [:scope, :branch, :object]
end

defmodule Transit.Station.Sdk.Catalog.Interpretation do
  @enforce_keys [:object, :revision, :digest]
  @derive {Inspect, only: []}
  defstruct [:object, :revision, :digest]
end

defmodule Transit.Station.Sdk.Catalog.Content do
  @enforce_keys [:bytes, :sha256]
  @derive {Inspect, only: []}
  defstruct [:bytes, :sha256]
end

defmodule Transit.Station.Sdk.Catalog.StoredDefinition do
  @enforce_keys [:interpretation, :content, :schema_fingerprint, :retired]
  @derive {Inspect, only: []}
  defstruct [:interpretation, :content, :schema_fingerprint, :retired]
end

defmodule Transit.Station.Sdk.Catalog.Basis do
  @enforce_keys [:definition, :connection, :principal, :namespace, :name, :interpretation]
  @derive {Inspect, only: []}
  defstruct [:definition, :connection, :principal, :namespace, :name, :interpretation]
end

defmodule Transit.Station.Sdk.Catalog.Metadata do
  @enforce_keys [:basis, :authorization, :position, :changed_lsn, :row_count, :schema]
  @derive {Inspect, only: []}
  defstruct [:basis, :authorization, :position, :changed_lsn, :row_count, :schema]
end

defmodule Transit.Station.Sdk.Catalog.Namespace do
  @enforce_keys [:scope, :id, :authorization, :name, :revision, :retired]
  @derive {Inspect, only: []}
  defstruct [:scope, :id, :authorization, :name, :revision, :retired]
end

defmodule Transit.Station.Sdk.Catalog.Entry do
  @enforce_keys [:interpretation, :namespace, :name, :position, :changed_lsn]
  @derive {Inspect, only: []}
  defstruct [:interpretation, :namespace, :name, :position, :changed_lsn]
end

defmodule Transit.Station.Sdk.Catalog.Cursor do
  @enforce_keys [:data]
  @derive {Inspect, only: []}
  defstruct [:data]
end

defmodule Transit.Station.Sdk.Catalog.Page do
  @enforce_keys [:position]
  @derive {Inspect, only: []}
  defstruct [:position, entries: [], next: nil, consistency: nil]
end

defmodule Transit.Station.Sdk.Catalog.Reference do
  @enforce_keys [:data]
  @derive {Inspect, only: []}
  defstruct [:data]
end

defmodule Transit.Station.Sdk.Catalog.SavedIntent do
  @enforce_keys [:data]
  @derive {Inspect, only: []}
  defstruct [:data]
end

defmodule Transit.Station.Sdk.Catalog.Intent do
  @enforce_keys [:id, :binding, :kind, :identity, :saved]
  @derive {Inspect, only: []}
  defstruct [:id, :binding, :kind, :identity, :saved]
end

defmodule Transit.Station.Sdk.Catalog.Compiled do
  @enforce_keys [:intent, :saved]
  @derive {Inspect, only: []}
  defstruct [:intent, :saved]
end

defmodule Transit.Station.Sdk.Catalog.Commit do
  @enforce_keys [:definition, :position, :matched, :affected, :live_rows]
  @derive {Inspect, only: []}
  defstruct [:definition, :position, :matched, :affected, :live_rows]
end

defmodule Transit.Station.Sdk.Catalog.Observation do
  @enforce_keys [:kind, :state, :reference]
  @derive {Inspect, only: []}
  defstruct [:kind, :state, :reference, commit: nil, phase: nil, reason: nil, position: nil]
end

defmodule Transit.Station.Sdk.Catalog.Current do
  @enforce_keys [:definition, :position, :changed_lsn, :row_count]
  @derive {Inspect, only: []}
  defstruct [:definition, :position, :changed_lsn, :row_count]
end

defmodule Transit.Station.Sdk.Catalog.Preview do
  @enforce_keys [:kind, :intent, :position]
  @derive {Inspect, only: []}
  defstruct [
    :kind,
    :intent,
    :position,
    current: nil,
    reason: nil,
    work: nil,
    rebuild_key: nil,
    schema_fingerprint: nil,
    matches: nil
  ]
end

defmodule Transit.Station.Sdk.Catalog.ReadAuthority do
  @enforce_keys [:database, :schema, :table]
  @derive {Inspect, only: []}
  defstruct [:database, :schema, :table]
end

defmodule Transit.Station.Sdk.Catalog.SnapshotOwner do
  @enforce_keys [:definition, :connection, :principal, :object, :operation]
  @derive {Inspect, only: []}
  defstruct [:definition, :connection, :principal, :object, :operation]
end

defmodule Transit.Station.Sdk.Catalog.SnapshotAcquisition do
  @enforce_keys [:owner, :expected]
  @derive {Inspect, only: []}
  defstruct [:owner, :expected]
end

defmodule Transit.Station.Sdk.Catalog.Snapshot do
  @enforce_keys [:owner, :content]
  @derive {Inspect, only: []}
  defstruct [:owner, :content]
end

defmodule Transit.Station.Sdk.Catalog.SnapshotStatus do
  @enforce_keys [
    :owner,
    :current_interpretation,
    :current_position,
    :retired,
    :released,
    :authority
  ]
  @derive {Inspect, only: []}
  defstruct [
    :owner,
    :current_interpretation,
    :current_position,
    :retired,
    :released,
    :authority,
    snapshot: nil
  ]
end

defmodule Transit.Station.Sdk.Catalog.SnapshotMetadata do
  @enforce_keys [
    :snapshot,
    :interpretation,
    :accepted,
    :changed_lsn,
    :row_count,
    :schema,
    :authority
  ]
  @derive {Inspect, only: []}
  defstruct [:snapshot, :interpretation, :accepted, :changed_lsn, :row_count, :schema, :authority]
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
    :metadata_page_entries,
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
    :metadata_page_entries,
    :resident_intents
  ]
end

defmodule Transit.Station.Sdk.Catalog.Description do
  @enforce_keys [:configuration, :subject, :policy_revision]
  @derive {Inspect, only: []}
  defstruct [:configuration, :subject, :policy_revision]
end

defmodule Transit.Station.Sdk.Catalog do
  @moduledoc "Direct Table lifecycle, original recovery and explicitly owned retained metadata."
  alias Transit.Client
  alias Transit.Station.Sdk.{Logical, Runner}

  alias __MODULE__.{
    Scope,
    TableLimits,
    Authority,
    Subject,
    Column,
    Schema,
    Counts,
    Assignment,
    Connection,
    Configuration,
    Identity,
    Position,
    ObjectIdentity,
    Interpretation,
    Content,
    StoredDefinition,
    Basis,
    Metadata,
    Namespace,
    Entry,
    Cursor,
    Page,
    Reference,
    SavedIntent,
    Intent,
    Compiled,
    Commit,
    Observation,
    Current,
    Preview,
    ReadAuthority,
    SnapshotOwner,
    SnapshotAcquisition,
    Snapshot,
    SnapshotStatus,
    SnapshotMetadata,
    Capabilities,
    Description
  }

  @shapes %{
    Scope => {:transit_catalog_scope, [:resource, :catalog]},
    TableLimits => {:transit_catalog_limits, [:record_bytes, :staging_bytes, :staging_records]},
    Authority =>
      {:transit_catalog_authority,
       [
         :database_domain,
         :schema_domain,
         :table_domain,
         :database,
         :initial_schema_authority,
         :initial_schema
       ]},
    Subject =>
      {:transit_catalog_subject,
       [:principal, :login_role, :role, :credential_epoch, :audience, :context]},
    Column =>
      {:transit_catalog_column,
       [:id, :name, :type, :nullable, :default, :max_characters, :encoding, :collation]},
    Schema =>
      {:transit_catalog_schema, [:object, :revision, :next_column, :columns, :primary_key]},
    Counts => {:transit_catalog_counts, [:matched, :changed]},
    Assignment => {:transit_catalog_assignment, [:column, :value]},
    Connection => {:transit_catalog_connection, [:scope, :audience, :branch, :role]},
    Configuration =>
      {:transit_catalog_configuration,
       [:scope, :branch, :partition, :audience, :authority, :database_name, :initial_schema_name]},
    Identity => {:transit_catalog_identity, [:operation, :namespace]},
    Position => {:transit_catalog_position, [:partition, :next_lsn]},
    ObjectIdentity => {:transit_catalog_object, [:scope, :branch, :object]},
    Interpretation => {:transit_catalog_interpretation, [:object, :revision, :digest]},
    Content => {:transit_catalog_content, [:bytes, :sha256]},
    StoredDefinition =>
      {:transit_catalog_stored, [:interpretation, :content, :schema_fingerprint, :retired]},
    Basis =>
      {:transit_catalog_basis,
       [:definition, :connection, :principal, :namespace, :name, :interpretation]},
    Metadata =>
      {:transit_catalog_metadata,
       [:basis, :authorization, :position, :changed_lsn, :row_count, :schema]},
    Namespace =>
      {:transit_catalog_namespace, [:scope, :id, :authorization, :name, :revision, :retired]},
    Entry =>
      {:transit_catalog_entry, [:interpretation, :namespace, :name, :position, :changed_lsn]},
    Cursor => {:transit_catalog_cursor, [:data]},
    Page => {:transit_catalog_page, [:position, :entries, :next, :consistency]},
    Reference => {:transit_catalog_reference, [:data]},
    SavedIntent => {:transit_catalog_saved_intent, [:data]},
    Intent => {:transit_catalog_intent, [:id, :binding, :kind, :identity, :saved]},
    Compiled => {:transit_catalog_compiled, [:intent, :saved]},
    Commit =>
      {:transit_catalog_commit, [:definition, :position, :matched, :affected, :live_rows]},
    Observation =>
      {:transit_catalog_observation,
       [:kind, :state, :reference, :commit, :phase, :reason, :position]},
    Current => {:transit_catalog_current, [:definition, :position, :changed_lsn, :row_count]},
    Preview =>
      {:transit_catalog_preview,
       [
         :kind,
         :intent,
         :position,
         :current,
         :reason,
         :work,
         :rebuild_key,
         :schema_fingerprint,
         :matches
       ]},
    ReadAuthority => {:transit_catalog_read_authority, [:database, :schema, :table]},
    SnapshotOwner =>
      {:transit_catalog_snapshot_owner,
       [:definition, :connection, :principal, :object, :operation]},
    SnapshotAcquisition => {:transit_catalog_snapshot_acquisition, [:owner, :expected]},
    Snapshot => {:transit_catalog_snapshot, [:owner, :content]},
    SnapshotStatus =>
      {:transit_catalog_snapshot_status,
       [
         :owner,
         :current_interpretation,
         :current_position,
         :retired,
         :snapshot,
         :released,
         :authority
       ]},
    SnapshotMetadata =>
      {:transit_catalog_snapshot_metadata,
       [:snapshot, :interpretation, :accepted, :changed_lsn, :row_count, :schema, :authority]},
    Capabilities =>
      {:transit_catalog_capabilities,
       [
         :version,
         :definition,
         :max_columns,
         :max_rows,
         :max_sql_bytes,
         :max_intent_bytes,
         :max_action_bytes,
         :metadata_page_entries,
         :resident_intents
       ]},
    Description => {:transit_catalog_description, [:configuration, :subject, :policy_revision]}
  }
  @tags Map.new(@shapes, fn {module, {tag, fields}} -> {tag, {module, fields}} end)

  def open(
        %Client.Config{} = config,
        %Client.Credential{} = credential,
        %Connection{} = connection,
        service_url \\ nil
      ) do
    with :ok <- Runner.compatible(),
         do:
           request(fn ->
             :transit_catalog.open(
               Client.native(config),
               Client.native(credential),
               native(connection),
               native(service_url)
             )
           end)
  end

  def close(client), do: result(:transit_catalog.close(client))
  def capabilities(client), do: request(fn -> :transit_catalog.capabilities(client) end)
  def describe(client), do: request(fn -> :transit_catalog.describe(client) end)
  def namespace(client, id), do: request(fn -> :transit_catalog.namespace(client, id) end)

  def namespaces(client, cursor \\ nil),
    do: request(fn -> :transit_catalog.namespaces(client, native(cursor)) end)

  def tables(client, namespace \\ 1, cursor \\ nil),
    do: request(fn -> :transit_catalog.tables(client, namespace, native(cursor)) end)

  def lookup(client, name, namespace \\ 1),
    do: request(fn -> :transit_catalog.lookup(client, name, namespace) end)

  def compile_sql(
        client,
        sql,
        identity,
        create_object \\ nil,
        dialect \\ :transit,
        ingestion \\ :point
      ),
      do:
        request(fn ->
          :transit_catalog.compile_sql(
            client,
            sql,
            native(identity),
            native(create_object),
            dialect,
            ingestion
          )
        end)

  def prepare(client, name, identity, operation),
    do:
      request(fn ->
        :transit_catalog.prepare(client, name, native(identity), native(operation))
      end)

  def load(client, saved), do: request(fn -> :transit_catalog.load(client, native(saved)) end)

  def forget(client, intent),
    do: request(fn -> :transit_catalog.forget(client, native(intent)) end)

  def preview(client, intent),
    do: request(fn -> :transit_catalog.preview(client, native(intent)) end)

  def stage(client, intent), do: request(fn -> :transit_catalog.stage(client, native(intent)) end)

  def admit(client, original),
    do: request(fn -> :transit_catalog.admit(client, native(original)) end)

  def inspect(client, original),
    do: request(fn -> :transit_catalog.inspect(client, native(original)) end)

  def execute(client, original, steps \\ 256),
    do: request(fn -> :transit_catalog.execute(client, native(original), steps) end)

  def cancel(client, original),
    do: request(fn -> :transit_catalog.cancel(client, native(original)) end)

  def prepare_snapshot(client, metadata, operation),
    do: request(fn -> :transit_catalog.prepare_snapshot(client, native(metadata), operation) end)

  def acquire_snapshot(client, acquisition),
    do: request(fn -> :transit_catalog.acquire_snapshot(client, native(acquisition)) end)

  def snapshot_status(client, owner),
    do: request(fn -> :transit_catalog.snapshot_status(client, native(owner)) end)

  def snapshot_metadata(client, snapshot),
    do: request(fn -> :transit_catalog.snapshot_metadata(client, native(snapshot)) end)

  def release_snapshot(client, snapshot),
    do: request(fn -> :transit_catalog.release_snapshot(client, native(snapshot)) end)

  def basis(%Metadata{basis: basis}), do: basis
  def save(value), do: request(fn -> :transit_catalog.save(native(value)) end)
  def restore(kind, data), do: request(fn -> :transit_catalog.restore(kind, data) end)

  defp request(fun) do
    fun.() |> result()
  rescue
    ArgumentError -> {:error, %Client.Error{kind: :invalid_argument, phase: :catalog_value}}
  end

  defp result({:ok, value}), do: {:ok, convert(value)}

  defp result({:uncertain, original, error}),
    do: {:uncertain, convert(original), Client.convert(error)}

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

  defp walk({:transit_catalog_client, _, _, _, _} = v, _, _, left), do: {v, left - 1}
  defp walk(%Client.ProcessRef{} = v, :native, _, left), do: {Client.native(v), left - 1}
  defp walk(%Client.ResourceRef{} = v, :native, _, left), do: {Client.native(v), left - 1}
  defp walk(%Logical.Field{} = v, :native, _, left), do: {Logical.native(v), left - 1}
  defp walk(%Logical.Element{} = v, :native, _, left), do: {Logical.native(v), left - 1}
  defp walk(%Logical.Alternative{} = v, :native, _, left), do: {Logical.native(v), left - 1}

  defp walk(%{__struct__: module} = v, :native, depth, left) when is_map_key(@shapes, module) do
    {tag, fields} = Map.fetch!(@shapes, module)
    {children, next} = children(Enum.map(fields, &Map.fetch!(v, &1)), :native, depth, left)
    {List.to_tuple([tag | children]), next}
  end

  defp walk({:transit_process, _, _} = v, :public, _, left), do: {Client.convert(v), left - 1}
  defp walk({:transit_resource, _, _} = v, :public, _, left), do: {Client.convert(v), left - 1}

  defp walk({:transit_logical_field, _, _, _, _} = v, :public, _, left),
    do: {Logical.convert(v), left - 1}

  defp walk({:transit_logical_element, _, _, _} = v, :public, _, left),
    do: {Logical.convert(v), left - 1}

  defp walk({:transit_logical_alternative, _, _, _} = v, :public, _, left),
    do: {Logical.convert(v), left - 1}

  defp walk(nil, :native, _, left), do: {:undefined, left - 1}
  defp walk(:undefined, :public, _, left), do: {nil, left - 1}

  defp walk(values, direction, depth, left) when is_list(values),
    do: children(values, direction, depth, left)

  defp walk(value, :public, depth, left)
       when is_tuple(value) and tuple_size(value) > 0 and is_map_key(@tags, elem(value, 0)) do
    {module, fields} = Map.fetch!(@tags, elem(value, 0))
    if tuple_size(value) != length(fields) + 1, do: raise(ArgumentError, "Catalog record shape")
    {values, next} = children(tl(Tuple.to_list(value)), :public, depth, left)
    {struct!(module, Enum.zip(fields, values)), next}
  end

  defp walk(value, direction, depth, left) when is_tuple(value) do
    {values, next} = children(Tuple.to_list(value), direction, depth, left)
    {List.to_tuple(values), next}
  end

  defp walk(value, _, _, left), do: {value, left - 1}

  defp children(values, direction, depth, left),
    do: Enum.map_reduce(values, left - 1, &walk(&1, direction, depth + 1, &2))
end
