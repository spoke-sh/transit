defmodule Transit.Station.Sdk.Catalog.Scope do
  @enforce_keys [:resource, :catalog]
  @derive {Inspect, only: []}
  defstruct [:resource, :catalog]
end

defmodule Transit.Station.Sdk.Catalog.Connection do
  @enforce_keys [:owner, :scope]
  @derive {Inspect, only: []}
  defstruct [:owner, :scope]
end

defmodule Transit.Station.Sdk.Catalog.Configuration do
  @enforce_keys [:scope, :owner, :administrator]
  @derive {Inspect, only: []}
  defstruct [:scope, :owner, :administrator]
end

defmodule Transit.Station.Sdk.Catalog.Schema do
  @enforce_keys [:names, :value_type]
  @derive {Inspect, only: []}
  defstruct [:names, :value_type]
end

defmodule Transit.Station.Sdk.Catalog.CreateTable do
  @enforce_keys [:scope, :operation, :object, :table, :name, :schema]
  @derive {Inspect, only: []}
  defstruct [:scope, :operation, :object, :table, :name, :schema]
end

defmodule Transit.Station.Sdk.Catalog.Policy do
  @enforce_keys [:scope, :principal, :revision, :inspect, :create]
  @derive {Inspect, only: []}
  defstruct [:scope, :principal, :revision, :inspect, :create]
end

defmodule Transit.Station.Sdk.Catalog.PolicyChange do
  @enforce_keys [:expected_revision, :policy]
  @derive {Inspect, only: []}
  defstruct [:expected_revision, :policy]
end

defmodule Transit.Station.Sdk.Catalog.Compiled do
  @enforce_keys [:request, :canonical]
  @derive {Inspect, only: []}
  defstruct [:request, :canonical]
end

defmodule Transit.Station.Sdk.Catalog.Prepared do
  @enforce_keys [:bytes]
  @derive {Inspect, only: []}
  defstruct [:bytes]
end

defmodule Transit.Station.Sdk.Catalog.Capabilities do
  @enforce_keys [
    :version,
    :definition,
    :initialize,
    :create_table,
    :conditional_policy,
    :current_metadata,
    :max_saved_bytes,
    :table_columns
  ]
  @derive {Inspect, only: []}
  defstruct [
    :version,
    :definition,
    :initialize,
    :create_table,
    :conditional_policy,
    :current_metadata,
    :max_saved_bytes,
    :table_columns
  ]
end

defmodule Transit.Station.Sdk.Catalog.Description do
  @enforce_keys [:configuration, :policy, :resource_revision]
  @derive {Inspect, only: []}
  defstruct [:configuration, :policy, :resource_revision]
end

defmodule Transit.Station.Sdk.Catalog.TableSource do
  @enforce_keys [:table, :schema]
  @derive {Inspect, only: []}
  defstruct [:table, :schema]
end

defmodule Transit.Station.Sdk.Catalog.Definition do
  @enforce_keys [:scope, :object, :revision, :name, :source, :principal, :operation, :input]
  @derive {Inspect, only: []}
  defstruct [:scope, :object, :revision, :name, :source, :principal, :operation, :input]
end

defmodule Transit.Station.Sdk.Catalog.Cursor do
  @enforce_keys [:definition, :scope, :resource_revision, :after_name]
  @derive {Inspect, only: []}
  defstruct [:definition, :scope, :resource_revision, :after_name]
end

defmodule Transit.Station.Sdk.Catalog.Page do
  @enforce_keys [:resource_revision, :entries, :next]
  @derive {Inspect, only: []}
  defstruct [:resource_revision, :entries, :next]
end

defmodule Transit.Station.Sdk.Catalog.Receipt do
  @enforce_keys [:request, :principal, :input, :outcome]
  @derive {Inspect, only: []}
  defstruct [:request, :principal, :input, :outcome]
end

defmodule Transit.Station.Sdk.Catalog.Disposition do
  @enforce_keys [:scope, :origin, :principal, :input, :payload, :outcome]
  @derive {Inspect, only: []}
  defstruct [:scope, :origin, :principal, :input, :payload, :outcome]
end

defmodule Transit.Station.Sdk.Catalog do
  @moduledoc """
  Explicit catalog controls and named Table creation through the shared Erlang
  worker and Zig owner. Persist Prepared.bytes before submission. Uncertainty
  retains the original command; Task loss does not cancel accepted work.
  """
  alias Transit.Client
  alias Transit.Station.Sdk.Runner

  alias __MODULE__.{
    Scope,
    Connection,
    Configuration,
    Schema,
    CreateTable,
    Policy,
    PolicyChange,
    Compiled,
    Prepared,
    Capabilities,
    Description,
    TableSource,
    Definition,
    Cursor,
    Page,
    Receipt,
    Disposition
  }

  def open(
        %Client.Config{} = config,
        %Client.Credential{} = credential,
        %Connection{} = connection
      ) do
    with :ok <- Runner.compatible(),
         do:
           result(
             :transit_catalog.open(
               Client.native(config),
               Client.native(credential),
               native(connection)
             )
           )
  end

  def close(client), do: result(:transit_catalog.close(client))
  def capabilities(client), do: result(:transit_catalog.capabilities(client))
  def describe(client), do: result(:transit_catalog.describe(client))
  def lookup(client, name), do: result(:transit_catalog.lookup(client, name))

  def definition(client, object, revision),
    do: result(:transit_catalog.definition(client, object, revision))

  def list(client), do: result(:transit_catalog.list(client))
  def list(client, %Cursor{} = cursor), do: result(:transit_catalog.list(client, native(cursor)))

  def compile_sql(client, sql, operation, object, table),
    do: result(:transit_catalog.compile_sql(client, sql, operation, object, table))

  def prepare_initialize(client, %Configuration{} = configuration),
    do: result(:transit_catalog.prepare_initialize(client, native(configuration)))

  def prepare_create(client, %CreateTable{} = request),
    do: result(:transit_catalog.prepare_create(client, native(request)))

  def prepare_policy(client, %PolicyChange{} = change),
    do: result(:transit_catalog.prepare_policy(client, native(change)))

  def submit(client, %Prepared{} = prepared),
    do: result(:transit_catalog.submit(client, native(prepared)))

  def observe(client, %Prepared{} = prepared, input),
    do: result(:transit_catalog.observe(client, native(prepared), input))

  def input_disposition(client, %Prepared{} = prepared, input),
    do: result(:transit_catalog.input_disposition(client, native(prepared), input))

  def status(client, %CreateTable{} = original),
    do: result(:transit_catalog.status(client, native(original)))

  defp result({:ok, value}), do: {:ok, convert(value)}

  defp result({:uncertain, prepared, error}),
    do: {:uncertain, convert(prepared), Client.convert(error)}

  defp result(error), do: Client.convert(error)

  @doc false

  def native(%Scope{} = v), do: {:transit_catalog_scope, Client.native(v.resource), v.catalog}

  def native(%Connection{} = v),
    do: {:transit_catalog_connection, Client.native(v.owner), native(v.scope)}

  def native(%Configuration{} = v),
    do: {:transit_catalog_configuration, native(v.scope), Client.native(v.owner), v.administrator}

  def native(%Schema{} = v), do: {:transit_catalog_schema, v.names, v.value_type}

  def native(%CreateTable{} = v),
    do:
      {:transit_catalog_create_table, native(v.scope), v.operation, v.object, v.table, v.name,
       native(v.schema)}

  def native(%Policy{} = v),
    do: {:transit_catalog_policy, native(v.scope), v.principal, v.revision, v.inspect, v.create}

  def native(%PolicyChange{} = v),
    do: {:transit_catalog_policy_change, v.expected_revision, native(v.policy)}

  def native(%Compiled{} = v), do: {:transit_catalog_compiled, native(v.request), v.canonical}

  def native(%Prepared{} = v), do: {:transit_catalog_prepared, v.bytes}

  def native(%Capabilities{} = v),
    do:
      {:transit_catalog_capabilities, v.version, v.definition, v.initialize, v.create_table,
       v.conditional_policy, v.current_metadata, v.max_saved_bytes, v.table_columns}

  def native(%Description{} = v),
    do:
      {:transit_catalog_description, native(v.configuration), native(v.policy),
       v.resource_revision}

  def native(%TableSource{} = v), do: {:transit_catalog_table_source, v.table, native(v.schema)}

  def native(%Definition{} = v),
    do:
      {:transit_catalog_definition, native(v.scope), v.object, v.revision, v.name,
       native(v.source), v.principal, v.operation, v.input}

  def native(%Cursor{} = v),
    do:
      {:transit_catalog_cursor, v.definition, native(v.scope), v.resource_revision, v.after_name}

  def native(%Page{} = v),
    do:
      {:transit_catalog_page, v.resource_revision, Enum.map(v.entries, &native/1), native(v.next)}

  def native(%Receipt{} = v),
    do: {:transit_catalog_receipt, native(v.request), v.principal, v.input, v.outcome}

  def native(%Disposition{} = v),
    do:
      {:transit_catalog_disposition, native(v.scope), v.origin, v.principal, v.input, v.payload,
       v.outcome}

  def native(%Client.AdmissionReceipt{position: position}), do: {:transit_admission, position}
  def native(nil), do: :undefined
  def native(value), do: value

  @doc false

  def convert({:transit_catalog_scope, resource, catalog}),
    do: %Scope{resource: Client.convert(resource), catalog: catalog}

  def convert({:transit_catalog_connection, owner, scope}),
    do: %Connection{owner: Client.convert(owner), scope: convert(scope)}

  def convert({:transit_catalog_configuration, scope, owner, administrator}),
    do: %Configuration{
      scope: convert(scope),
      owner: Client.convert(owner),
      administrator: administrator
    }

  def convert({:transit_catalog_schema, names, value_type}),
    do: %Schema{names: names, value_type: value_type}

  def convert({:transit_catalog_create_table, scope, operation, object, table, name, schema}),
    do: %CreateTable{
      scope: convert(scope),
      operation: operation,
      object: object,
      table: table,
      name: name,
      schema: convert(schema)
    }

  def convert({:transit_catalog_policy, scope, principal, revision, inspect, create}),
    do: %Policy{
      scope: convert(scope),
      principal: principal,
      revision: revision,
      inspect: inspect,
      create: create
    }

  def convert({:transit_catalog_policy_change, expected_revision, policy}),
    do: %PolicyChange{expected_revision: expected_revision, policy: convert(policy)}

  def convert({:transit_catalog_compiled, request, canonical}),
    do: %Compiled{request: convert(request), canonical: canonical}

  def convert({:transit_catalog_prepared, bytes}), do: %Prepared{bytes: bytes}

  def convert(
        {:transit_catalog_capabilities, version, definition, initialize, create_table,
         conditional_policy, current_metadata, max_saved_bytes, table_columns}
      ),
      do: %Capabilities{
        version: version,
        definition: definition,
        initialize: initialize,
        create_table: create_table,
        conditional_policy: conditional_policy,
        current_metadata: current_metadata,
        max_saved_bytes: max_saved_bytes,
        table_columns: table_columns
      }

  def convert({:transit_catalog_description, configuration, policy, resource_revision}),
    do: %Description{
      configuration: convert(configuration),
      policy: convert(policy),
      resource_revision: resource_revision
    }

  def convert({:transit_catalog_table_source, table, schema}),
    do: %TableSource{table: table, schema: convert(schema)}

  def convert(
        {:transit_catalog_definition, scope, object, revision, name, source, principal, operation,
         input}
      ),
      do: %Definition{
        scope: convert(scope),
        object: object,
        revision: revision,
        name: name,
        source: convert(source),
        principal: principal,
        operation: operation,
        input: input
      }

  def convert({:transit_catalog_cursor, definition, scope, resource_revision, after_name}),
    do: %Cursor{
      definition: definition,
      scope: convert(scope),
      resource_revision: resource_revision,
      after_name: after_name
    }

  def convert({:transit_catalog_page, resource_revision, entries, next}),
    do: %Page{
      resource_revision: resource_revision,
      entries: Enum.map(entries, &convert/1),
      next: convert(next)
    }

  def convert({:transit_catalog_receipt, request, principal, input, outcome}),
    do: %Receipt{request: convert(request), principal: principal, input: input, outcome: outcome}

  def convert({:transit_catalog_disposition, scope, origin, principal, input, payload, outcome}),
    do: %Disposition{
      scope: convert(scope),
      origin: origin,
      principal: principal,
      input: input,
      payload: payload,
      outcome: outcome
    }

  def convert({:transit_admission, _} = value), do: Client.convert(value)
  def convert(:undefined), do: nil
  def convert(value), do: value
end
