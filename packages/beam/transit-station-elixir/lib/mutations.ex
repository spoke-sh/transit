defmodule Transit.Station.Sdk.Mutations.Connection do
  @enforce_keys [:writer, :resource, :table]
  @derive {Inspect, only: []}
  defstruct [:writer, :resource, :table]
end

defmodule Transit.Station.Sdk.Mutations.Reference do
  @enforce_keys [:bytes]
  @derive {Inspect, only: []}
  defstruct [:bytes]
end

defmodule Transit.Station.Sdk.Mutations.Compiled do
  @enforce_keys [:request, :reference]
  @derive {Inspect, only: []}
  defstruct [:request, :reference]
end

defmodule Transit.Station.Sdk.Mutations.Prepared do
  @enforce_keys [:bytes]
  @derive {Inspect, only: []}
  defstruct [:bytes]
end

defmodule Transit.Station.Sdk.Mutations.Description do
  @enforce_keys [
    :resource,
    :table,
    :names,
    :value_type,
    :resource_revision,
    :policy_revision,
    :declaration,
    :permissions
  ]
  @derive {Inspect, only: []}
  defstruct [
    :resource,
    :table,
    :names,
    :value_type,
    :resource_revision,
    :policy_revision,
    :declaration,
    :permissions,
    active: nil
  ]
end

defmodule Transit.Station.Sdk.Mutations.Conflict do
  @enforce_keys [:key, :row]
  defstruct [:key, :row]
end

defmodule Transit.Station.Sdk.Mutations.Status do
  @enforce_keys [
    :reference,
    :principal,
    :table,
    :declaration,
    :policy_revision,
    :phase,
    :affected_rows,
    :reason,
    :input,
    :conflict
  ]
  @derive {Inspect, only: [:phase, :affected_rows]}
  defstruct [
    :reference,
    :principal,
    :table,
    :declaration,
    :policy_revision,
    :phase,
    :affected_rows,
    :reason,
    :input,
    :conflict
  ]
end

defmodule Transit.Station.Sdk.Mutations do
  @moduledoc """
  Explicit Table mutation callers through the owned Erlang worker and shared Zig
  implementation. Persist Prepared.bytes before submission; uncertainty returns
  the original prepared value. Task loss does not cancel accepted work.
  """
  alias Transit.Client
  alias Transit.Station.Sdk.Runner
  alias __MODULE__.{Connection, Reference, Compiled, Prepared, Description, Status, Conflict}

  def open(
        %Client.Config{} = config,
        %Client.Credential{} = credential,
        %Connection{} = connection
      ) do
    with :ok <- Runner.compatible(),
         do:
           result(
             :transit_mutations.open(
               Client.native(config),
               Client.native(credential),
               native(connection)
             )
           )
  end

  def close(client), do: result(:transit_mutations.close(client))
  def describe(client), do: result(:transit_mutations.describe(client))

  def compile_sql(client, name, sql, namespace),
    do: result(:transit_mutations.compile_sql(client, name, sql, namespace))

  def prepare_next(client, %Compiled{} = compiled),
    do: result(:transit_mutations.prepare_next(client, native(compiled)))

  def prepare_control(client, control, %Reference{} = reference),
    do: result(:transit_mutations.prepare_control(client, control, native(reference)))

  def submit(client, %Prepared{} = prepared),
    do: result(:transit_mutations.submit(client, native(prepared)))

  def observe(client, %Prepared{} = prepared, input),
    do: result(:transit_mutations.observe(client, native(prepared), input))

  def rejection(client, %Prepared{} = prepared, input),
    do: result(:transit_mutations.rejection(client, native(prepared), input))

  def status(client, %Reference{} = reference),
    do: result(:transit_mutations.status(client, native(reference)))

  defp result({:ok, value}), do: {:ok, convert(value)}

  defp result({:uncertain, prepared, error}),
    do: {:uncertain, convert(prepared), Client.convert(error)}

  defp result(error), do: Client.convert(error)

  @doc false
  def native(%Connection{} = v),
    do:
      {:transit_mutation_connection, Client.native(v.writer), Client.native(v.resource), v.table}

  def native(%Reference{} = v), do: {:transit_mutation_reference, v.bytes}
  def native(%Compiled{} = v), do: {:transit_mutation_compiled, v.request, native(v.reference)}
  def native(%Prepared{} = v), do: {:transit_mutation_prepared, v.bytes}

  def native(%Description{} = v),
    do:
      {:transit_mutation_description, Client.native(v.resource), v.table, v.names, v.value_type,
       v.resource_revision, v.policy_revision, v.declaration, v.permissions, native(v.active)}

  def native(%Conflict{} = v), do: {:transit_mutation_conflict, v.key, v.row}

  def native(%Status{} = v),
    do:
      {:transit_mutation_status, native(v.reference), v.principal, v.table, v.declaration,
       v.policy_revision, v.phase, v.affected_rows, v.reason, v.input, native(v.conflict)}

  def native(%Client.AdmissionReceipt{position: position}), do: {:transit_admission, position}
  def native(nil), do: :undefined
  def native(value), do: value

  @doc false
  def convert({:transit_mutation_connection, writer, resource, table}),
    do: %Connection{
      writer: Client.convert(writer),
      resource: Client.convert(resource),
      table: table
    }

  def convert({:transit_mutation_reference, bytes}), do: %Reference{bytes: bytes}

  def convert({:transit_mutation_compiled, request, reference}),
    do: %Compiled{request: request, reference: convert(reference)}

  def convert({:transit_mutation_prepared, bytes}), do: %Prepared{bytes: bytes}

  def convert(
        {:transit_mutation_description, resource, table, names, value_type, resource_revision,
         policy_revision, declaration, permissions, active}
      ),
      do: %Description{
        resource: Client.convert(resource),
        table: table,
        names: names,
        value_type: value_type,
        resource_revision: resource_revision,
        policy_revision: policy_revision,
        declaration: declaration,
        permissions: permissions,
        active: convert(active)
      }

  def convert(
        {:transit_mutation_status, reference, principal, table, declaration, policy_revision,
         phase, affected_rows, reason, input, conflict}
      ),
      do: %Status{
        reference: convert(reference),
        principal: principal,
        table: table,
        declaration: declaration,
        policy_revision: policy_revision,
        phase: phase,
        affected_rows: affected_rows,
        reason: reason,
        input: input,
        conflict: convert(conflict)
      }

  def convert({:transit_mutation_conflict, key, row}), do: %Conflict{key: key, row: row}
  def convert({:transit_admission, _} = value), do: Client.convert(value)
  def convert(:undefined), do: nil
  def convert(value), do: value
end
